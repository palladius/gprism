require 'minitest/autorun'
require 'fileutils'
require 'digest'
require 'openssl'

class TestGprism < Minitest::Test
  def setup
    @workdir = File.expand_path("..", __dir__)
    @bin = File.join(@workdir, "bin", "gprism")
    
    # We create a dummy test dir for files
    @test_dir = File.join(@workdir, "tmp_test_dir")
    FileUtils.mkdir_p(@test_dir)
    
    # Switch to test dir
    Dir.chdir(@test_dir)
    
    # Create test .env config
    File.write(".env", <<~ENV)
      GPRISM_PROJECT_ID=palladius-genai
      GPRISM_IDENTITY=palladiusbonton@gmail.com
      GPRISM_ENVIRONMENT=test
    ENV
    
    ENV['GIT_PRIVATIZE_KEY'] = 'test-encryption-key-123'
    
    # Create a secret file to privatize
    @secret_file = "my_secret_file.txt"
    @secret_content = "super_secret_value_#{Time.now.to_i}"
    File.write(@secret_file, @secret_content)
    
    # Create git-privatize.list
    File.write(".git-privatize.list", @secret_file)
    
    url = `git config --get remote.origin.url 2>/dev/null`.strip
    if url.empty?
      repo_slug = "unknown-repo"
    else
      if url.include?(":") && !url.start_with?("http")
        url = url.split(":", 2).last
      end
      url = url.sub(%r{^https?://[^/]+/}, "")
      url = url.sub(/\.git$/, "")
      repo_slug = url.gsub(/[^a-zA-Z0-9]/, '-').gsub(/-+/, '-').sub(/^-/, '').sub(/-$/, '')
    end
    @secret_name = "test--#{repo_slug}--my-secret-file-txt"
  end

  def teardown
    # Clean up GCP secrets
    system("gcloud secrets delete #{@secret_name} --project=palladius-genai --quiet >/dev/null 2>&1")
    
    # Clean up files
    Dir.chdir(@workdir)
    FileUtils.rm_rf(@test_dir)
  end

  def test_push_and_pull
    # Ensure it's not in gitignore
    File.delete(".gitignore") if File.exist?(".gitignore")

    # 1. PUSH
    out = `#{@bin} push --all`.gsub(/\e\[\d+m/, '')
    assert_includes out, "SUCCESS: Pushed #{@secret_file} to Secret Manager as #{@secret_name}"
    
    # Verify local file is replaced by readme
    refute File.exist?(@secret_file), "Secret file should be deleted after push"
    assert File.exist?("#{@secret_file}.readme"), "Readme should be created"
    
    # Verify gitignore updated
    assert File.exist?(".gitignore")
    assert_includes File.read(".gitignore"), @secret_file
    
    # Verify GCP secret is encrypted
    enc_content = `gcloud secrets versions access latest --secret=#{@secret_name} --project=palladius-genai 2>/dev/null`.strip
    require 'base64'
    decoded_enc_content = Base64.strict_decode64(enc_content)
    assert decoded_enc_content.start_with?("Salted__"), "GCP secret should be encrypted"
    refute_includes decoded_enc_content, @secret_content
    
    # 2. STATUS
    status_out = `#{@bin} status`.gsub(/\e\[\d+m/, '')
    assert_includes status_out, "In GCP"
    assert_includes status_out, "Local Readme"
    
    # 3. PULL
    pull_out = `#{@bin} pull --all`.gsub(/\e\[\d+m/, '')
    assert_includes pull_out, "SUCCESS: Restored #{@secret_file} from GCP"
    
    # Verify local file is restored and decrypted
    assert File.exist?(@secret_file), "Secret file should be restored"
    assert_equal @secret_content, File.read(@secret_file), "Decrypted content should match original"
    refute File.exist?("#{@secret_file}.readme"), "Readme should be deleted after pull"
  end
end
