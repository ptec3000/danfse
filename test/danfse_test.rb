require "test_helper"

class DanfseTest < Minitest::Test
  def test_version
    assert_equal "0.1.0", Danfse::VERSION
  end

  def test_error_hierarchy
    assert_operator Danfse::InvalidXml, :<, Danfse::Error
    assert_operator Danfse::Error, :<, StandardError
  end

  def test_root_points_to_gem
    assert Danfse::ROOT.join("danfse.gemspec").exist?
  end
end
