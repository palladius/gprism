# frozen_string_literal: true

require 'fileutils'
require 'tempfile'
require 'open3'
require 'digest'
load File.expand_path('../bin/gprism', __dir__)

def assert(condition, msg = "Assertion failed")
  unless condition
    puts "\e[31m[FAIL] #{msg}\e[0m"
    caller_info = caller[0].split(':in ').first
    puts "  at #{caller_info}"
    exit 1
  end
end

def assert_equal(expected, actual, msg = nil)
  assert expected == actual, msg || "Expected: #{expected.inspect}, Got: #{actual.inspect}"
end

def run_cmd(cmd, env = {})
  stdout, stderr, status = Open3.capture3(env, cmd)
  [stdout, stderr, status.exitstatus]
end

# Color helpers
def green(s);  "\e[32m#{s}\e[0m"; end
def bold(s);   "\e[1m#{s}\e[0m"; end

puts bold("Starting gprism Test Suite...")

# ----------------------------------------------------
# Test Case 1: Core Encryption / Decryption Helpers
# ----------------------------------------------------
print "Testing symmetric encryption engine... "
test_data = "Hello secret world! 1234567890-=_+[]{}|;:,.<>?/"
test_pass = "my-secure-crypto-password-42"

encrypted = encrypt(test_data, test_pass)
assert encrypted.is_a?(String), "Encrypted payload should be a String"
assert encrypted.start_with?("U2FsdGVkX1"), "Base64 payload should start with Salted__ prefix"

decrypted = decrypt(encrypted, test_pass)
assert_equal test_data, decrypted, "Decrypted data must match original text"

# Verify wrong password failure
begin
  res = decrypt(encrypted, "wrong-password")
  puts "DEBUG: decrypt with wrong password returned: #{res.inspect}"
  assert false, "Decryption with wrong password should have failed"
rescue => e
  puts "DEBUG: rescue caught: #{e.message}"
  assert e.message.include?("Decryption failed"), "Expected decryption failure error message"
end
puts green("[PASS]")

# ----------------------------------------------------
# Test Case 2: Name Slug Generation & Truncation
# ----------------------------------------------------
print "Testing Secret Manager name mapping and truncation... "
config = { 'environment' => 'dev' }
remote_url = "git@github.com:palladius/test-repo.git"

# Normal path
name1 = determine_secret_name("config/database.yml", remote_url, config)
assert_equal "gp--dev--github-com--palladius--test-repo--config-database-yml", name1

# Dot file
name2 = determine_secret_name(".env", remote_url, config)
assert_equal "gp--dev--github-com--palladius--test-repo--env", name2

# Extremely long path (triggers truncation and hashing)
long_path = "a" * 300
name_long = determine_secret_name(long_path, remote_url, config)
assert name_long.length <= 255, "Secret name should be truncated under 255 characters"
assert name_long.include?("--"), "Truncated name should include double-hyphen hash separator"
puts green("[PASS]")

# ----------------------------------------------------
# Test Case 3: List File Loading
# ----------------------------------------------------
print "Testing list file loader (.git-privatize.list)... "
Dir.mktmpdir do |dir|
  list_content = <<~LIST
    # This is a comment
    .env
    config/master.key
    
    # Another comment
    secrets/prod.json
  LIST
  File.write(File.join(dir, '.git-privatize.list'), list_content)
  files = load_list_files(dir)
  assert_equal ['.env', 'config/master.key', 'secrets/prod.json'], files
end
puts green("[PASS]")

# ----------------------------------------------------
# Test Case 4: End-to-End Command Line Integration
# ----------------------------------------------------
puts "Running End-to-End CLI tests in a sandbox repository..."

Dir.mktmpdir("gprism-sandbox") do |sandbox|
  gprism_bin = File.expand_path(File.join(__dir__, "../bin/gprism"))
  
  # Setup configuration
  config_dir = File.join(sandbox, "config")
  FileUtils.mkdir_p(config_dir)
  config_file = File.join(config_dir, "config.yaml")
  File.write(config_file, <<~YAML)
    gcp_project_id: "palladius-genai"
    environment: "dev"
  YAML
  
  # Setup git repository
  repo_dir = File.join(sandbox, "test-repo")
  FileUtils.mkdir_p(repo_dir)
  
  # Initialize repo and configure dummy origin
  _, _, s = run_cmd("git init", { "GIT_DIR" => nil })
  assert_equal 0, s, "Failed to init sandbox git repository"
  
  Dir.chdir(repo_dir) do
    run_cmd("git init")
    run_cmd("git remote add origin git@github.com:palladius/sandbox-test.git")
    
    # Create test secret files
    File.write(".env", "DB_PASSWORD=supersecret-123\nPORT=3000")
    FileUtils.mkdir_p("config")
    File.write("config/master.key", "aes-key-xyz-789")
    
    # Create list file
    File.write(".git-privatize.list", ".env\nconfig/master.key")
    
    # Run status before pushing
    stdout, stderr, code = run_cmd("#{gprism_bin} status -p palladius-genai -e dev")
    assert_equal 0, code, "gprism status failed: #{stderr}"
    
    # Test pushing all secrets
    puts " -> Pushing secrets to GCP Secret Manager..."
    test_key = "test-crypto-key-999"
    env_vars = { 
      "GIT_PRIVATIZE_KEY" => test_key
    }
    
    stdout, stderr, code = run_cmd("#{gprism_bin} push --all -p palladius-genai -e dev", env_vars)
    puts "DEBUG STDOUT: #{stdout}"
    puts "DEBUG STDERR: #{stderr}"
    assert_equal 0, code, "gprism push --all failed: #{stderr}\n#{stdout}"
    
    # Check that secrets were created and are in Secret Manager
    assert stdout.include?("Successfully uploaded to Secret Manager"), "Upload success message missing"
    assert File.exist?(".env.readme"), "Breadcrumb for .env not created"
    assert File.exist?("config/master.key.readme"), "Breadcrumb for master.key not created"
    
    # Check .gitignore was updated
    assert File.exist?(".gitignore"), ".gitignore not created"
    gitignore_content = File.read(".gitignore")
    assert gitignore_content.include?(".env"), ".env not ignored"
    assert gitignore_content.include?("config/master.key"), "master.key not ignored"
    
    # Verify status command now
    stdout, stderr, code = run_cmd("#{gprism_bin} status -p palladius-genai -e dev", env_vars)
    assert_equal 0, code, "gprism status failed: #{stderr}"
    assert stdout.include?("OK"), "Status should report OK"
    
    # Verify that secret payload is encrypted
    secret_name_env = determine_secret_name(".env", "git@github.com:palladius/sandbox-test.git", { 'environment' => 'dev' })
    secret_name_key = determine_secret_name("config/master.key", "git@github.com:palladius/sandbox-test.git", { 'environment' => 'dev' })
    
    puts " -> Verifying encrypted payload in GCP..."
    gcp_stdout, _, _ = run_cmd("gcloud secrets versions access latest --secret=#{secret_name_env} --project=palladius-genai")
    assert gcp_stdout.start_with?("U2FsdGVkX1"), "Secret in Secret Manager is not encrypted"
    
    # Delete local secrets to test pulling
    File.delete(".env")
    File.delete("config/master.key")
    
    # Check status reports RESTORE REQUIRED
    stdout, stderr, code = run_cmd("#{gprism_bin} status -p palladius-genai -e dev", env_vars)
    assert stdout.include?("RESTORE REQUIRED"), "Status should show RESTORE REQUIRED"
    
    # Test pulling all secrets
    puts " -> Pulling secrets..."
    stdout, stderr, code = run_cmd("#{gprism_bin} pull --all -p palladius-genai -e dev", env_vars)
    assert_equal 0, code, "gprism pull failed: #{stderr}"
    
    # Assert they are back and match originals
    assert File.exist?(".env"), ".env not restored"
    assert File.exist?("config/master.key"), "master.key not restored"
    
    assert_equal "DB_PASSWORD=supersecret-123\nPORT=3000", File.read(".env"), ".env content corrupted"
    assert_equal "aes-key-xyz-789", File.read("config/master.key"), "master.key content corrupted"
    
    # Test pulling with wrong key fails
    File.delete(".env")
    stdout, stderr, code = run_cmd("#{gprism_bin} pull -p palladius-genai -e dev", env_vars.merge("GIT_PRIVATIZE_KEY" => "wrong-key"))
    assert stdout.include?("Error decrypting"), "Decrypt should have failed on wrong key"
    assert !File.exist?(".env"), "File should not be created if decryption fails"
    
    # Cleanup GCP secrets created during testing
    puts " -> Cleaning up test secrets in Google Cloud..."
    run_cmd("gcloud secrets delete #{secret_name_env} --quiet --project=palladius-genai")
    run_cmd("gcloud secrets delete #{secret_name_key} --quiet --project=palladius-genai")
  end
end

puts green("✔ All tests passed successfully!")
