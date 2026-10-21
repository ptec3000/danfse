# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "pdf-reader"
require "stringio"

class CliTest < Minitest::Test
  XML_PATH = File.expand_path("fixtures/real/acervo_homologacao_rtc.xml", __dir__)
  ROOT = File.expand_path("..", __dir__)

  def run_cli(*arguments)
    Open3.capture3(RbConfig.ruby, "-Ilib", "exe/danfse", *arguments, chdir: ROOT)
  end

  def pdf_text(bytes)
    PDF::Reader.new(StringIO.new(bytes.b)).pages.map(&:text).join("\n")
  end

  def watermark(bytes)
    page = PDF::Reader.new(StringIO.new(bytes.b)).pages.first
    page.runs(merge: false, skip_overlapping: false)
      .select { |run| run.font_size > 40 }.map(&:text).join
  end

  def test_writes_pdf_to_stdout
    stdout, stderr, status = run_cli(XML_PATH)
    assert_equal 0, status.exitstatus, stderr
    assert stdout.start_with?("%PDF")
    assert_includes pdf_text(stdout), "DANFSe v2.0"
    assert_empty stderr
  end

  def test_writes_pdf_to_destination
    Dir.mktmpdir do |directory|
      destination = File.join(directory, "saida.pdf")
      stdout, stderr, status = run_cli(XML_PATH, destination)
      assert_equal 0, status.exitstatus, stderr
      assert File.binread(destination).start_with?("%PDF")
      assert_empty stdout
      assert_empty stderr
    end
  end

  def test_invalid_xml_exits_with_error_without_writing_pdf
    Dir.mktmpdir do |directory|
      source = File.join(directory, "invalido.xml")
      destination = File.join(directory, "saida.pdf")
      File.write(source, "<invalid>")
      stdout, stderr, status = run_cli(source, destination)
      assert_equal 1, status.exitstatus
      assert_match(/\AXML da NFS-e inválido: .+/, stderr)
      refute_includes stderr, "XML inválido:"
      assert_equal 1, stderr.scan("XML da NFS-e inválido:").length
      assert_empty stdout
      refute File.exist?(destination)
    end
  end

  def test_missing_arguments_prints_usage_and_exits_64
    stdout, stderr, status = run_cli
    assert_equal 64, status.exitstatus
    assert_includes stderr, "Uso: danfse"
    assert_empty stdout
  end

  def test_cancelled_option
    stdout, stderr, status = run_cli("--cancelada", XML_PATH)
    assert_equal 0, status.exitstatus, stderr
    assert_equal "CANCELADA", watermark(stdout)
  end

  def test_substituted_option
    stdout, stderr, status = run_cli("--substituida", XML_PATH)
    assert_equal 0, status.exitstatus, stderr
    assert_equal "SUBSTITUÍDA", watermark(stdout)
  end

  def test_receipt_option
    stdout, stderr, status = run_cli("--canhoto", XML_PATH)
    assert_equal 0, status.exitstatus, stderr
    assert_includes pdf_text(stdout), "IDENTIFICAÇÃO E ASSINATURA"
  end

  def test_unknown_option_exits_64
    stdout, stderr, status = run_cli("--desconhecida", XML_PATH)
    assert_equal 64, status.exitstatus
    assert_includes stderr, "Uso: danfse"
    assert_empty stdout
  end

  def test_extra_argument_exits_64
    stdout, stderr, status = run_cli(XML_PATH, "saida.pdf", "extra")
    assert_equal 64, status.exitstatus
    assert_includes stderr, "Uso: danfse"
    assert_empty stdout
  end

  def test_conflicting_situations_exit_64
    stdout, stderr, status = run_cli("--cancelada", "--substituida", XML_PATH)
    assert_equal 64, status.exitstatus
    assert_includes stderr, "Uso: danfse"
    assert_empty stdout
  end

  def test_missing_file_exits_with_readable_error
    stdout, stderr, status = run_cli("/danfse/nonexistent.xml")
    assert_equal 1, status.exitstatus
    assert_includes stderr, "Erro ao acessar arquivo:"
    assert_empty stdout
  end
end
