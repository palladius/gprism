# encoding: utf-8
Encoding.default_external = Encoding::UTF_8
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
    
    # Initialize a git repo so gprism thinks this is the git root
    system("git init >/dev/null 2>&1")
    
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
    File.write(".git-privatize.list", "#{@secret_file}\n")
    
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
    
    # Verify local file is NOT replaced by readme
    assert File.exist?(@secret_file), "Secret file should still exist after push"
    refute File.exist?("#{@secret_file}.readme"), "Readme should not be created"
    
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
    assert_includes status_out, "Sync | 🔑 SM | 💻 Local"
    
    # 3. PULL
    pull_out = `#{@bin} pull --all`.gsub(/\e\[\d+m/, '')
    assert_includes pull_out, "is identical to remote secret #{@secret_name}. Skipping pull."
    
    # Verify local file is restored and decrypted
    assert File.exist?(@secret_file), "Secret file should be restored"
    assert_equal @secret_content, File.read(@secret_file), "Decrypted content should match original"
    refute File.exist?("#{@secret_file}.readme"), "Readme should be deleted after pull"
  end
  def test_add_folder
    # Create a dummy folder
    folder_name = "dummy_folder"
    FileUtils.mkdir_p(folder_name)

    # Try to add the folder
    out = `#{@bin} add #{folder_name} 2>&1`.gsub(/\e\[\d+m/, '')
    
    # Assert it returns an error
    assert_includes out, "ERROR: Folders are not supported. Please add individual files."
    refute_equal 0, $?.exitstatus, "Should exit with non-zero status"
  end

  def test_subfolder_execution
    # Create subfolder and file
    subfolder = "test_subfolder_dir"
    FileUtils.mkdir_p(subfolder)
    file_path = File.join(subfolder, "sub_secret.txt")
    File.write(file_path, "subfolder secret")

    # Change to subfolder and run add
    out = nil
    Dir.chdir(subfolder) do
      # Running bin/gprism from inside subfolder
      bin_path = File.expand_path("../bin/gprism", __dir__)
      out = `#{bin_path} add sub_secret.txt 2>&1`.gsub(/\e\[\d+m/, '')
      
      # It should NOT create .git-privatize.list or .gitignore in the subfolder
      refute File.exist?(".git-privatize.list"), "Should not create .git-privatize.list in subfolder"
      refute File.exist?(".gitignore"), "Should not create .gitignore in subfolder"
      refute File.exist?(".env.template"), "Should not create .env.template anywhere via add/st"
    end

    # Check that it updated the ROOT .git-privatize.list with the relative path
    assert File.exist?(".git-privatize.list"), "Root list should exist"
    assert_includes File.read(".git-privatize.list"), file_path
    assert_includes out, "SUCCESS: Added #{file_path} to .git-privatize.list"
  end

  def test_status_binary
    binary_file = "my_binary.jpg"
    File.write(binary_file, "fake_binary_data" * 10000) # 160KB
    File.open(".git-privatize.list", "a") { |f| f.puts(binary_file) }

    # Push to GCS
    out = `#{@bin} push -f --all`.gsub(/\e\[\d+m/, '')
    assert_includes out, "Offloading to GCS"

    # Status should report Sync with GS
    status_out = `#{@bin} status`.gsub(/\e\[\d+m/, '')
    assert_includes status_out, "Sync | 🪣 GS | 💻 Local"
  end
end
