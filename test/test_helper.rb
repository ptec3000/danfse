$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "danfse"
require "minitest/autorun"

module FixtureHelper
  def fixture(name) = File.read(File.expand_path("fixtures/#{name}", __dir__))
end
Minitest::Test.include FixtureHelper
