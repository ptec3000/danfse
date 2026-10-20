require "pathname"
require_relative "danfse/version"

module Danfse
  class Error < StandardError; end
  class InvalidXml < Error; end

  ROOT = Pathname(__dir__).parent
end
