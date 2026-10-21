# frozen_string_literal: true

require "test_helper"
require "pdf-reader"
require "stringio"
require "tmpdir"

class DocumentTest < Minitest::Test
  class PaintedTextReceiver < PDF::Reader::PageTextReceiver
    attr_reader :painted_text, :font_texts

    def page=(page)
      super
      @painted_text = +""
      @font_texts = Hash.new { |hash, key| hash[key] = +"" }
    end

    private

    def internal_show_text(string)
      font = state.current_font
      decoded = font.unpack(string).map { |code| font.to_utf8(code) }.join
      @painted_text << decoded
      @font_texts[font.basefont] << decoded
      super
    end
  end

  def painted_text(page)
    receiver = PaintedTextReceiver.new
    page.walk(receiver)
    receiver.painted_text
  end

  def reader(xml, **opts) = PDF::Reader.new(StringIO.new(Danfse.render(xml, **opts)))
  def text(xml, **opts) = reader(xml, **opts).pages.map(&:text).join("\n")

  def test_sefin_typography_is_painted_at_readable_sizes
    page = reader(fixture("com_tomador_pf_destinatario_intermediario.xml"), canhoto: true).pages.first
    runs = page.runs
    {"DANFSe v2.0" => 9.5, "CNPJ / CPF / NIF" => 7,
     "CHAVE DE ACESSO DA NFS-E" => 7.5, "SERVIÇO PRESTADO" => 8.5, "Descrição do Serviço" => 8}.each do |label, size|
      matching = runs.select { |run| run.text == label }
      assert matching.any? { |run| (run.font_size - size).abs < 0.01 }, label
    end
    assert runs.any? { |run| run.text.include?("Pessoa") && (run.font_size - 8).abs < 0.01 }
  end

  def test_collapsed_messages_are_regular_and_centered
    page = reader(fixture("locacao_nao_incidencia.xml")).pages.first
    receiver = PaintedTextReceiver.new
    page.walk(receiver)
    regular = receiver.font_texts.find { |name, _| name.to_s.end_with?("LiberationSans") }.last
    assert_includes regular, Danfse::Layout::NO_ISSQN
    runs = page.runs(merge: true).select { |run| run.text.include?("OPERAÇÃO NÃO SUJEITA") }
    assert_equal 1, runs.size
    run = runs.first
    assert_in_delta page.attributes[:MediaBox][2] / 2, run.x + run.width / 2, 2
  end

  def test_collapsed_bands_have_no_full_width_shading
    page = reader(fixture("locacao_nao_incidencia.xml")).pages.first
    rectangles = page.raw_content.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re/)
    full_width = rectangles.select { |rectangle| (rectangle[2].to_f - Danfse::Layout.cm(Danfse::Layout::WIDTH)).abs < 0.00001 }
    assert_equal 1, full_width.size # Only the header background spans all columns.
    assert_in_delta Danfse::Layout.cm(Danfse::Layout::HEADER[:background][:h]), full_width.first[3].to_f.abs, 0.00001
  end

  def test_complementary_totals_have_a_blank_line_before_them
    page = reader(fixture("real/locacao_homologacao_rtc.xml")).pages.first
    runs = page.runs
    item = runs.find { |run| run.text.include?("Total Simples Nacional:") }
    totals = runs.find { |run| run.text.include?("Totais Aproximados dos Tributos") }
    assert_in_delta 8, item.font_size, 0.01
    assert_in_delta 8, totals.font_size, 0.01
    assert_operator item.y - totals.y, :>=, 18
  end

  def test_identification_and_header_values_remain_complete_at_larger_sizes
    xml = fixture("com_tomador_pf_destinatario_intermediario.xml")
    nfse = Danfse::Nfse.new(xml)
    drawn = painted_text(reader(xml, canhoto: true).pages.first).gsub(/\s+/, "")
    (Danfse::Layout::IDENTIFICATION.keys + %i[ambiente_gerador tipo_ambiente]).each do |name|
      assert_includes drawn, nfse.public_send(name).to_s.gsub(/\s+/, "")
    end
  end

  def test_provider_simple_national_value_stays_on_one_line_without_growing_its_block
    xml = fixture("real/acervo_homologacao_rtc.xml")
    document = Danfse::Document.new(Danfse::Nfse.new(xml))
    page = PDF::Reader.new(StringIO.new(document.render)).pages.first
    value_runs = page.runs.select { |run| run.text.include?("Optante") || run.text == "de ..." }

    assert_equal 1, value_runs.size
    assert_equal "Optante - Microempresa ou Empresa de ...", value_runs.first.text
    assert_in_delta 7, value_runs.first.font_size, 0.01
    assert_in_delta Danfse::Layout::BASE_HEIGHTS[:prestador], document.heights[:prestador], 0.001
  end

  def test_short_field_that_cannot_fit_at_seven_points_is_truncated_on_one_line
    xml = fixture("com_tomador_pf_destinatario_intermediario.xml").sub(
      "<xNome>Pessoa Exemplo</xNome>", "<xNome>#{"Nome empresarial muito extenso " * 12}</xNome>")
    page = reader(xml).pages.first
    value_runs = page.runs.select { |run| run.text.include?("Nome empresarial muito extenso") }

    assert_equal 1, value_runs.size
    assert_includes value_runs.first.text, "..."
    assert_equal 7, value_runs.first.font_size
  end

  def test_header_metadata_uses_single_lines_and_truncates_long_municipalities
    municipality = "Município com nome muito extenso " * 12
    xml = fixture("real/acervo_homologacao_rtc.xml").sub(
      "<xLocEmi>Belo Horizonte</xLocEmi>", "<xLocEmi>#{municipality}</xLocEmi>")
    nfse = Danfse::Nfse.new(xml)
    page = PDF::Reader.new(StringIO.new(Danfse::Document.new(nfse).render)).pages.first
    header_runs = page.runs.select do |run|
      run.x > Danfse::Layout.cm(15.5) && run.y > 790
    end
    municipality_run = header_runs.find { |run| run.text.include?("Município:") }
    environment_run = header_runs.find { |run| run.text.include?("Ambiente Gerador:") }
    type_run = header_runs.find { |run| run.text.include?("Tipo de Ambiente:") }

    assert_equal 3, header_runs.size
    assert_includes municipality_run.text, "..."
    assert_equal 6, municipality_run.font_size
    assert_equal nfse.ambiente_gerador, environment_run.text
    assert_operator environment_run.font_size, :<, Danfse::Layout::ENVIRONMENT_SIZE
    assert_operator environment_run.font_size, :>=, 6
    assert_equal nfse.tipo_ambiente, type_run.text
    assert_equal 3, header_runs.map(&:y).uniq.size
  end

  def test_municipal_tax_description_has_visible_ellipsis_when_its_box_overflows
    description = "Descrição do código nacional para consultoria tecnológica e assistência especializada em planejamento e desenvolvimento contínuo de serviços digitais completos"
    xml = fixture("real/acervo_homologacao_rtc.xml").sub(
      /<xTribMun>.*?<\/xTribMun>/, "<xTribMun>#{description}</xTribMun>")
    drawn = painted_text(reader(xml).pages.first)

    assert_includes drawn, "Descrição do código nacional"
    assert_match(/Descrição do código nacional[^\n]*\.\.\./, drawn)
    refute_includes drawn, "digitais completos"
  end

  def test_very_long_provider_email_renders_within_two_seconds
    email = "contato" + ("abc" * 3_300) + "@example.com"
    xml = fixture("com_tomador_pf_destinatario_intermediario.xml").sub(
      "</prest>", "<email>#{email}</email></prest>")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    page = reader(xml).pages.first
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 2
    assert_match(/contato[abc]+\.\.\./, painted_text(page))
  end

  def test_a4_single_page
    r = reader(fixture("real/acervo_homologacao_rtc.xml"))
    assert_equal 1, r.page_count
    box = r.pages.first.attributes[:MediaBox]
    assert_in_delta 595.28, box[2], 1
    assert_in_delta 841.89, box[3], 1
  end

  def test_main_text
    t = text(fixture("real/acervo_homologacao_rtc.xml"))
    ["DANFSe v2.0", "Documento Auxiliar da NFS-e", "NFS-e SEM VALIDADE JURÍDICA",
     "31062002251944463000142000000000056526102354211157", "ACERVO TECH INOVA SIMPLES",
     "TOMADOR/ADQUIRENTE DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e", "Teste DanfseJob (homologacao)",
     "A autenticidade desta NFS-e"].each { |s| assert_includes t, s }
    refute_includes t, "NFS3106" # access key without the XML prefix
  end

  def test_collapsed_recipient_draws_same_customer_message
    drawn = painted_text(reader(fixture("com_tomador_pj.xml")).pages.first)
    assert_includes drawn, "O DESTINATÁRIO É O PRÓPRIO TOMADOR/ADQUIRENTE DA OPERAÇÃO"
  end

  def test_non_incident_issqn_draws_municipal_message
    drawn = painted_text(reader(fixture("locacao_nao_incidencia.xml")).pages.first)
    assert_includes drawn, "TRIBUTAÇÃO MUNICIPAL (ISSQN) - OPERAÇÃO NÃO SUJEITA AO ISSQN"
  end

  def test_absent_intermediary_draws_missing_message
    drawn = painted_text(reader(fixture("real/acervo_homologacao_rtc.xml")).pages.first)
    assert_includes drawn, "INTERMEDIÁRIO DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e"
  end

  def test_heights_snapshot_is_frozen_and_does_not_expose_internal_state
    document = Danfse::Document.new(Danfse::Nfse.new(fixture("real/acervo_homologacao_rtc.xml")))
    document.render
    snapshot = document.heights
    assert_predicate snapshot, :frozen?
    assert_raises(FrozenError) { snapshot[:service] = 0 }
    refute_same snapshot, document.heights
    assert_equal snapshot, document.heights
    refute_respond_to document, :heights=
  end

  def test_production_without_test_warning
    xml = fixture("real/acervo_homologacao_rtc.xml").sub("<tpAmb>2</tpAmb>", "<tpAmb>1</tpAmb>")
    refute_includes text(xml), "SEM VALIDADE JURÍDICA"
  end

  def test_watermarks
    xml = fixture("real/acervo_homologacao_rtc.xml")
    [:cancelada, :substituida].zip(["CANCELADA", "SUBSTITUÍDA"]).each do |situation, expected|
      page = reader(xml, situacao: situation).pages.first
      glyphs = page.runs(merge: false, skip_overlapping: false)
      watermark = glyphs.select { |run| run.font_size > 40 }.map(&:text).join
      assert_equal expected, watermark
      assert_operator glyphs.first.font_size, :>, 40
    end
    refute_includes text(xml), "CANCELADA"
    assert_raises(ArgumentError) { Danfse.render(xml, situacao: :outra) }
  end

  def test_optional_receipt
    xml = fixture("real/acervo_homologacao_rtc.xml")
    refute_includes text(xml), "IDENTIFICAÇÃO E ASSINATURA"
    assert_includes text(xml, canhoto: true), "IDENTIFICAÇÃO E ASSINATURA"
  end

  def test_long_description_single_page # Review Focus 3 and 5
    r = reader(fixture("descricao_longa.xml"))
    assert_equal 1, r.page_count
  end

  def test_all_fixtures_render
    Dir[File.expand_path("fixtures/**/*.xml", __dir__)].each do |path|
      assert_equal 1, PDF::Reader.new(StringIO.new(Danfse.render(File.read(path)))).page_count, path
    end
  end

  def test_visible_description_ellipsis # Review Focus 3
    t = text(fixture("descricao_longa.xml"))
    assert_includes t.gsub(/\s+/, ""), "..."
  end

  def test_full_document_with_receipt
    r = reader(fixture("com_tomador_pf_destinatario_intermediario.xml"), canhoto: true)
    assert_equal 1, r.page_count
    t = r.pages.first.text
    assert_includes t, "Totais Aproximados dos Tributos" # the mandatory line is never truncated
  end

  def test_literal_labels
    t = text(fixture("com_tomador_pj.xml"))
    ["CNPJ / CPF / NIF", "Código IBGE / CEP", "BC ISSQN", "IRRF", "Ambiente Gerador:", "Tipo de Ambiente:"].each { |s| assert_includes t, s }
    refute_includes t, "Cnpj"
  end

  def test_pis_cofins_hidden_in_2027
    refute_includes text(fixture("competencia_2027.xml")), "PIS - Débito Apuração Própria"
    assert_includes text(fixture("real/acervo_homologacao_rtc.xml")), "PIS - Débito Apuração Própria"
  end

  def test_render_file
    Dir.mktmpdir do |dir|
      out = File.join(dir, "nota.pdf")
      src = File.join(dir, "nota.xml")
      File.write(src, fixture("real/acervo_homologacao_rtc.xml"))
      assert_equal out, Danfse.render_file(src, out)
      assert File.binread(out).start_with?("%PDF")
    end
  end
  def test_header_prefixes_are_not_duplicated_and_municipality_can_be_omitted
    xml = fixture("real/acervo_homologacao_rtc.xml")
    t = text(xml)
    assert_equal 1, t.scan("Ambiente Gerador:").size
    assert_equal 1, t.scan("Tipo de Ambiente:").size
    assert_equal 1, t.scan("Município:").size
    xml = xml.sub(/<cTribNac>.*?<\/cTribNac>/, "<cTribNac>990101</cTribNac>")
    refute_includes text(xml), "Município:"
  end

  def test_both_federal_optional_fields_disappear_together
    t = text(fixture("competencia_2027.xml"))
    refute_includes t, "COFINS - Débito Apuração Própria"
    refute_includes t, "Descrição Contrib. Sociais"
    assert_includes text(fixture("real/acervo_homologacao_rtc.xml")), "Nenhum"
  end

  def test_missing_glyph_is_replaced_and_custom_font_roles_work
    xml = fixture("real/acervo_homologacao_rtc.xml").sub("Teste DanfseJob", "Teste 🦄 漢 DanfseJob")
    t = text(xml, fonts: {regular: Danfse::FONT_DIR.join("LiberationSans-Regular.ttf"),
      bold: Danfse::FONT_DIR.join("LiberationSans-Bold.ttf")})
    assert_includes t, "Teste ? ? DanfseJob"
    assert_includes t, "JURÍDICA"
  end

  def test_watermark_is_opaque_and_precedes_content
    r = reader(fixture("real/acervo_homologacao_rtc.xml"), situacao: :cancelada)
    page = r.pages.first
    content = page.raw_content
    assert_match(/0\.65098[0-9]* 0\.65098[0-9]* 0\.65098[0-9]* (?:rg|scn)/, content)
    refute_match(/\/\w+ gs\b/, content)
    fonts = page.objects.deref(page.attributes[:Resources][:Font]).values
    assert fonts.all? { |font| page.objects.deref(font)[:Subtype] == :TrueType }
  end

  def test_height_budget_and_description_priority
    xml = fixture("real/acervo_homologacao_rtc.xml")
    short = Danfse::Document.new(Danfse::Nfse.new(xml))
    short.render
    long = Danfse::Document.new(Danfse::Nfse.new(fixture("descricao_longa.xml")))
    long.render
    short_plan = short.heights
    long_plan = long.heights
    assert_in_delta 0.32, short_plan[:tomador], 0.001
    assert_operator long_plan[:service], :>, short_plan[:service]
    assert_in_delta short_plan.values.sum, long_plan.values.sum, 0.001
    assert_operator long_plan[:complementary], :>=, 0.7
  end

  def test_long_complementary_text_keeps_all_tax_totals
    xml = fixture("substituicao.xml").sub(/<xInfComp>.*?<\/xInfComp>/m,
      "<xInfComp>#{'Complemento ' * 400}</xInfComp>")
    r = reader(xml, canhoto: true)
    assert_equal 1, r.page_count
    t = r.pages.first.text.gsub(/\s+/, " ")
    assert_includes t, "..."
    assert_includes t, "Totais Aproximados dos Tributos"
    %w[Federais: Estaduais: Municipais:].each { |label| assert_includes t, label }
  end

  def test_identification_labels_and_complete_authenticity_text
    t = text(fixture("real/acervo_homologacao_rtc.xml"))
    %w[chave numero competencia emissao_nfse numero_dps serie_dps emissao_dps].each do |name|
      assert_includes t, Danfse::Layout::IDENTIFICATION.fetch(name.to_sym)[:label]
    end
    page = reader(fixture("real/acervo_homologacao_rtc.xml")).pages.first
    drawn = painted_text(page)
    assert_includes drawn.gsub(/\s+/, ""), Danfse::Layout::AUTHENTICITY.gsub(/\s+/, "")
    region = PDF::Reader::Rectangle.new(Danfse::Layout.cm(15.80), 720,
      Danfse::Layout.cm(20.52), 750)
    assert_equal 3, page.runs(rect: region).map(&:y).uniq.size
  end

  def test_long_short_fields_keep_their_ellipsis_and_all_labels_are_painted
    page = reader(fixture("com_tomador_pf_destinatario_intermediario.xml"), canhoto: true).pages.first
    drawn = painted_text(page)
    assert_includes drawn.gsub(/\s+/, ""), "Empresa de ...".gsub(/\s+/, "")
    [Danfse::Layout::IDENTIFICATION, *Danfse::Layout::PEOPLE.values,
      Danfse::Layout::SERVICE, Danfse::Layout::FEDERAL, Danfse::Layout::IBS,
      Danfse::Layout::TOTALS, Danfse::Layout::RECEIPT].each do |fields|
      fields.each_value do |field|
        next unless field[:label]

        assert_includes drawn, field[:label]
      end
    end
  end

  def test_each_dark_qr_module_is_drawn_at_the_prescribed_position
    nfse = Danfse::Nfse.new(fixture("real/acervo_homologacao_rtc.xml"))
    document = Danfse::Document.new(nfse)
    page = PDF::Reader.new(StringIO.new(document.render)).pages.first
    rectangles = page.raw_content.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re/).map do |values|
      values.map(&:to_f)
    end
    unit = Danfse::Layout.cm(1.52) / document.qr_modules.size
    modules = rectangles.select { |rect| (rect[2] - unit).abs < 0.00001 && (rect[3] - unit).abs < 0.00001 }
    expected = []
    document.qr_modules.each_with_index do |row, y|
      row.each_with_index do |dark, x|
        expected << [Danfse::Layout.cm(17.48) + x * unit,
          page.attributes[:MediaBox][3] - Danfse::Layout.cm(1.67) - (y + 1) * unit, unit, unit] if dark
      end
    end
    assert_equal expected.length, modules.length
    expected.zip(modules).each do |target, actual|
      target.zip(actual).each { |a, b| assert_in_delta a, b, 0.00001 }
    end
  end

  def test_geometric_overflow_has_visible_ellipsis_without_character_truncation
    xml = fixture("real/acervo_homologacao_rtc.xml").sub(/<xDescServ>.*?<\/xDescServ>/m,
      "<xDescServ>#{"Serviço\n" * 100}FINAL INVISÍVEL</xDescServ>")
    refute_includes Danfse::Nfse.new(xml).descricao_servico, "..."
    page = reader(xml, canhoto: true).pages.first
    drawn = painted_text(page)
    assert_includes drawn, "..."
    refute_includes drawn, "FINAL INVISÍVEL"
    assert_includes drawn, "Totais Aproximados dos Tributos"
    assert_includes drawn, "IDENTIFICAÇÃO E ASSINATURA"
  end

  def test_complementary_geometric_overflow_reserves_the_tax_line
    xml = fixture("substituicao.xml").sub(/<xInfComp>.*?<\/xInfComp>/m,
      "<xInfComp>#{"Informação\n" * 100}FINAL INVISÍVEL</xInfComp>")
    page = reader(xml, canhoto: true).pages.first
    drawn = painted_text(page)
    assert_includes drawn, "..."
    refute_includes drawn, "FINAL INVISÍVEL"
    assert_includes drawn, Danfse::Nfse.new(xml).totais_tributos
    assert_includes drawn, "Nº NFS-e / CHAVE NFS-e"
  end

  def test_optional_row_heights_and_receipt_space_are_reallocated
    xml = fixture("real/acervo_homologacao_rtc.xml")
    with_receipt = Danfse::Document.new(Danfse::Nfse.new(xml), canhoto: true)
    without_receipt = Danfse::Document.new(Danfse::Nfse.new(xml))
    [with_receipt, without_receipt].each(&:render)
    a = with_receipt.heights
    b = without_receipt.heights
    assert_in_delta 0.80, b[:complementary] - a[:complementary], 0.001
    assert_in_delta 2.42, a[:municipal], 0.001
    assert_in_delta Danfse::Layout::BOTTOM, Danfse::Layout::START_Y + a.values.sum, 0.001
    assert_in_delta Danfse::Layout::BOTTOM, Danfse::Layout::START_Y + b.values.sum, 0.001
    xml = xml.sub(/<regEspTrib>.*?<\/regEspTrib>/, "")
    page = reader(xml).pages.first
    refute_includes painted_text(page), "Regime Especial de Tributação do ISSQN"
    refute_includes painted_text(page), "Benefício Municipal"
  end

  def test_block_titles_have_the_annex_field_background
    page = reader(fixture("real/acervo_homologacao_rtc.xml")).pages.first
    field = Danfse::Layout::PEOPLE[:prestador][:title].merge(y: Danfse::Layout::START_Y, h: Danfse::Layout::TITLE_HEIGHT)
    expected = [Danfse::Layout.cm(field[:x]),
      page.attributes[:MediaBox][3] - Danfse::Layout.cm(field[:y] + field[:h]),
      Danfse::Layout.cm(field[:w]), Danfse::Layout.cm(field[:h])]
    rectangles = page.raw_content.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re/)
    assert rectangles.any? { |rectangle| rectangle.map(&:to_f).zip(expected).all? { |a, b| (a - b).abs < 0.00001 } }
  end

  def test_custom_regular_and_bold_roles_are_used_for_content_and_titles
    page = reader(fixture("real/acervo_homologacao_rtc.xml"), fonts: {
      regular: Danfse::FONT_DIR.join("LiberationSans-Bold.ttf"),
      bold: Danfse::FONT_DIR.join("LiberationSans-Regular.ttf"),
    }).pages.first
    receiver = PaintedTextReceiver.new
    page.walk(receiver)
    content = receiver.font_texts.find { |name, _text| name.to_s.end_with?("LiberationSans-Bold") }.last
    titles = receiver.font_texts.find { |name, _text| name.to_s.end_with?("LiberationSans") }.last
    assert_includes content, "Teste DanfseJob (homologacao)"
    assert_includes titles, "DANFSe v2.0"
  end

  def test_description_receives_spare_height_before_long_complementary_text
    xml = fixture("real/acervo_homologacao_rtc.xml").sub(/<xDescServ>.*?<\/xDescServ>/m,
      "<xDescServ>#{"Serviço\n" * 100}FINAL SERVIÇO</xDescServ>")
    xml = xml.sub("</serv>", "<infoCompl><xInfComp>#{"Extra\n" * 100}FINAL COMPLEMENTO</xInfComp></infoCompl></serv>")
    page = reader(xml).pages.first
    drawn = painted_text(page)
    assert_operator drawn.scan("Serviço").size, :>, 2 # The base description box fits only two lines.
    refute_includes drawn, "FINAL COMPLEMENTO"
    complementary = drawn.split("INFORMAÇÕES COMPLEMENTARES", 2).last.split("Totais Aproximados dos Tributos", 2).first
    assert_match(/\.\.\.\z/, complementary.rstrip)
    assert_includes drawn, Danfse::Nfse.new(xml).totais_tributos
    assert_includes drawn, "..."
    refute_includes drawn, "FINAL SERVIÇO"
  end

  def test_real_rental_pdf_has_customer_and_non_incident_issqn_on_one_page
    pdf = reader(fixture("real/locacao_homologacao_rtc.xml"))
    assert_equal 1, pdf.page_count
    drawn = painted_text(pdf.pages.first)
    assert_includes drawn, "TRIBUTAÇÃO MUNICIPAL (ISSQN) - OPERAÇÃO NÃO SUJEITA AO ISSQN"
    assert_includes drawn, "Cliente Exemplo"
  end

  def test_missing_font_roles_raise_argument_error
    [{}, {regular: Danfse::FONT_DIR.join("LiberationSans-Regular.ttf")},
      {bold: Danfse::FONT_DIR.join("LiberationSans-Bold.ttf")},
      {"regular" => "regular.ttf", "bold" => "bold.ttf"}].each do |fonts|
      error = assert_raises(ArgumentError) do
        Danfse.render(fixture("real/acervo_homologacao_rtc.xml"), fonts: fonts)
      end
      assert_equal "fonts: precisa das chaves :regular e :bold", error.message
    end
  end

  def test_heights_are_available_before_render
    document = Danfse::Document.new(Danfse::Nfse.new(fixture("real/acervo_homologacao_rtc.xml")))
    heights = document.heights
    assert heights.frozen?
    assert_in_delta Danfse::Layout::BOTTOM, Danfse::Layout::START_Y + heights.values.sum, 0.001
    pdf = PDF::Reader.new(StringIO.new(document.render))
    assert_equal 1, pdf.page_count
    assert_equal heights, document.heights
  end

  def test_tabs_in_service_text_are_rendered_as_spaces
    xml = fixture("real/acervo_homologacao_rtc.xml").sub(/<xDescServ>.*?<\/xDescServ>/m,
      "<xDescServ>Antes&#9;Depois</xDescServ>")
    drawn = painted_text(reader(xml).pages.first)
    assert_includes drawn, "Antes Depois"
    refute_includes drawn, "Antes?Depois"
  end

end
