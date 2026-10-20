require "pathname"
require_relative "danfse/version"

module Danfse
  class Error < StandardError; end
  class InvalidXml < Error; end

  ROOT = Pathname(__dir__).parent
  FONT_DIR = ROOT.join("assets/fonts")
  LOGO_PATH = ROOT.join("assets/logo-nfse.png")
end

require_relative "danfse/municipios"
