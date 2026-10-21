# frozen_string_literal: true

require "pathname"
require "prawn"
require "rqrcode"
require_relative "danfse/version"

module Danfse
  class Error < StandardError; end
  class InvalidXml < Error; end

  ROOT = Pathname(__dir__).parent
  FONT_DIR = ROOT.join("assets/fonts")
  LOGO_PATH = ROOT.join("assets/logo-nfse.png")

  def self.render(xml, situacao: :normal, canhoto: false, fonts: nil)
    Document.new(Nfse.new(xml), situacao: situacao, canhoto: canhoto, fonts: fonts).render
  end

  def self.render_file(xml_path, pdf_path, **options)
    File.binwrite(pdf_path, render(File.read(xml_path), **options))
    pdf_path
  end
end

require_relative "danfse/municipios"
require_relative "danfse/formatters"
require_relative "danfse/tables"

require_relative "danfse/nfse"

require_relative "danfse/layout"
require_relative "danfse/document"
