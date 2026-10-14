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
    @identity = ENV['GPRISM_TEST_IDENTITY'] || 'ricc@gcp.altostrat.com'
    File.write(".env", <<~ENV)
      GPRISM_PROJECT_ID=palladius-genai
      GPRISM_IDENTITY=#{@identity}
      GPRISM_ENVIRONMENT=test
    ENV
    
    ENV['GIT_PRIVATIZE_KEY'] = 'test-encryption-key-123'
    
    # Clean up any pre-existing secret before running
    @test_id = "#{Time.now.to_i}-#{rand(1000..9999)}"
    @secret_name = "test--unknown-repo--my-secret-file-#{@test_id}-txt"
    @secret_file = "my-secret-file-#{@test_id}.txt"
    @secret_content = "super_secret_value_#{@test_id}"
    File.write(@secret_file, @secret_content)
    
    # Create .cache/gprism/tracked.list
    FileUtils.mkdir_p(".cache/gprism")
    File.write(".cache/gprism/tracked.list", "#{@secret_file}\n")
  end

  def teardown
    # Clean up GCP secrets
    system("gcloud secrets delete #{@secret_name} --project=palladius-genai --account=#{@identity} --quiet >/dev/null 2>&1")
    if @extra_secrets
      @extra_secrets.each do |sec|
        system("gcloud secrets delete #{sec} --project=palladius-genai --account=#{@identity} --quiet >/dev/null 2>&1")
      end
    end
    
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
    enc_content = `gcloud secrets versions access latest --secret=#{@secret_name} --project=palladius-genai --account=#{@identity} 2>/dev/null`.strip
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
      
      # It should NOT create .cache, .git-privatize.list or .gitignore in the subfolder
      refute File.exist?(".cache/gprism/tracked.list"), "Should not create cache list in subfolder"
      refute File.exist?(".git-privatize.list"), "Should not create .git-privatize.list in subfolder"
      refute File.exist?(".gitignore"), "Should not create .gitignore in subfolder"
      refute File.exist?(".env.template"), "Should not create .env.template anywhere via add/st"
    end

    # Check that it updated the ROOT .cache/gprism/tracked.list with the relative path and did NOT create .git-privatize.list
    assert File.exist?(".cache/gprism/tracked.list"), "Root cache list should exist"
    refute File.exist?(".git-privatize.list"), "Root .git-privatize.list should no longer be created"
    assert_includes File.read(".cache/gprism/tracked.list"), file_path
    assert_includes out, "SUCCESS: Added #{file_path} to .cache/gprism/tracked.list"
  end

  def test_status_binary
    binary_file = "my_binary.jpg"
    File.write(binary_file, "fake_binary_data" * 10000) # 160KB
    File.open(".cache/gprism/tracked.list", "a") { |f| f.puts(binary_file) }
    @extra_secrets = ["test--unknown-repo--my-binary-jpg"]

    # Push to GCS
    out = `#{@bin} push -f --all`.gsub(/\e\[\d+m/, '')
    assert_includes out, "Offloading to GCS"

    # Status should report Sync with GS
    status_out = `#{@bin} status`.gsub(/\e\[\d+m/, '')
    assert_includes status_out, "Sync | 🪣 GS | 💻 Local"
  end

  def test_default_no_args_shows_help
    out = `#{@bin}`.gsub(/\e\[\d+m/, '')
    assert_includes out, "Usage:"
    assert_includes out, "show, inspect <file>"
  end

  def test_version_flags
    ["--version", "-v", "version"].each do |flag|
      out = `#{@bin} #{flag}`.strip
      assert_equal "gprism 0.3.8", out
      assert_equal 0, $?.exitstatus
    end
  end

  def test_untracked_env_in_status_and_auto_fix
    # In setup, .cache/gprism/tracked.list has only @secret_file, so .env is untracked
    status_out = `#{@bin} status`.gsub(/\e\[\d+m/, '')
    assert_includes status_out, "⚠️ Untracked"
    assert_includes status_out, "WARN: 1 secret file(s) exist but are NOT tracked in .cache/gprism/tracked.list!"
    assert_includes status_out, ".env"
    assert_includes status_out, "gprism status --fix"

    # Now run status --fix
    fix_out = `#{@bin} status --fix`.gsub(/\e\[\d+m/, '')
    assert_includes fix_out, "Auto-fixing .cache/gprism/tracked.list"
    assert_includes File.read(".cache/gprism/tracked.list"), ".env"

    # Now run status again: .env is no longer untracked
    status_out_after = `#{@bin} status`.gsub(/\e\[\d+m/, '')
    refute_includes status_out_after, "⚠️ Untracked"
    refute_includes status_out_after, "NOT tracked in .cache/gprism/tracked.list"
  end

  def test_init_auto_seeds_env
    FileUtils.rm_rf(".cache")
    File.delete(".git-privatize.list") if File.exist?(".git-privatize.list")
    assert File.exist?(".env")

    out = `#{@bin} init`.gsub(/\e\[\d+m/, '')
    assert File.exist?(".cache/gprism/tracked.list")
    assert_includes File.read(".cache/gprism/tracked.list"), ".env"
    assert_includes out, "Added .env to .cache/gprism/tracked.list"
  end

  def test_show_and_modified_status
    # First push the secret created in setup
    `#{@bin} push --all`

    # Show should display Sync and MD5 matching
    show_out = `#{@bin} show #{@secret_file}`.gsub(/\e\[\d+m/, '')
    assert_includes show_out, "HERE (Local)"
    assert_includes show_out, "THERE (Remote 🔑 SM)"
    assert_includes show_out, "[ ✅ MATCHES LOCAL ]"
    assert_includes show_out, "Everything is in sync!"

    # Now modify local file
    File.write(@secret_file, "MODIFIED_VALUE_#{Time.now.to_i}")

    # Status should report M (modified vs remote)
    status_out = `#{@bin} status`.gsub(/\e\[\d+m/, '')
    assert_includes status_out, "⚠️ M "
    assert_includes status_out, "file(s) have local modifications (M)"

    # Show should now report diff and mismatch
    show_mod = `#{@bin} show #{@secret_file}`.gsub(/\e\[\d+m/, '')
    assert_includes show_mod, "[ ⚠️ DOES NOT MATCH LOCAL ]"
    assert_includes show_mod, "Difference Details (TEXTUAL File Diff: HERE vs THERE):"
    assert_includes show_mod, "MODIFIED_VALUE_"
  end

  def test_remote_discovery_without_privatize_list
    repo_slug = "palladius-test-repo-#{@test_id}"
    system("git remote add origin https://github.com/palladius/test-repo-#{@test_id}.git >/dev/null 2>&1")

    FileUtils.mkdir_p("private")
    second_file = "private/other-computer-tricks.md"
    second_content = "pushed_from_other_computer_#{@test_id}"
    File.write(second_file, second_content)

    first_sec = "test--#{repo_slug}--my-secret-file-#{@test_id}-txt"
    second_sec = "test--#{repo_slug}--private-other-computer-tricks-md"
    @extra_secrets = [first_sec, second_sec]

    # Push first file via --all and second file directly (simulating another computer)
    `#{@bin} push --all`
    `#{@bin} push #{second_file}`

    # Now simulate Computer B: remove second_file from disk AND remove local cache completely!
    File.delete(second_file)
    FileUtils.rm_rf(".cache")

    # 1. Status should still discover BOTH secrets directly from Secret Manager!
    st_out = `#{@bin} status`.gsub(/\e\[\d+m/, '')
    assert_includes st_out, @secret_file
    assert_includes st_out, second_file
    assert_includes st_out, "❌ Miss | 🔑 SM | ❌ Local"

    # 2. Pull -a should pull the missing second_file even without any prior cache!
    FileUtils.rm_rf(".cache")
    pull_out = `#{@bin} pull -a`.gsub(/\e\[\d+m/, '')
    assert_includes pull_out, "SUCCESS: Restored #{second_file} from GCP (read-only)"
    assert File.exist?(second_file), "Second file should be pulled to disk"
    assert_equal second_content, File.read(second_file)
    assert File.exist?(".cache/gprism/tracked.list"), "Cache should be populated in .cache/gprism/tracked.list"
  end
end
