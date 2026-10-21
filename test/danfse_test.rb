require "test_helper"
require "tmpdir"

class DanfseTest < Minitest::Test
  def test_gem_files_are_available_when_gemspec_is_loaded_elsewhere
    Dir.mktmpdir do |directory|
      files = Dir.chdir(directory) do
        Gem::Specification.load(Danfse::ROOT.join("danfse.gemspec").to_s).files
      end
      assert_includes files, "lib/danfse.rb"
      assert_includes files, "data/municipios.csv"
      assert_includes files, "assets/logo-nfse.png"
    end
  end
end
