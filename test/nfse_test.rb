# frozen_string_literal: true

require "test_helper"
require "nokogiri"

class NfseTest < Minitest::Test
  def real = Danfse::Nfse.new(fixture("real/acervo_homologacao_rtc.xml"))

  def test_real_identification
    n = real
    assert_equal "31062002251944463000142000000000056526102354211157", n.chave
    assert_equal "565", n.numero
    assert_equal "20/10/2026", n.competencia
    assert_equal "20/10/2026 18:55:01", n.emissao_nfse
    assert_equal "892569028", n.numero_dps
    assert_equal "900", n.serie_dps
    assert_equal "Prestador", n.emitente
    assert n.homologacao?
    assert_equal "https://www.nfse.gov.br/ConsultaPublica/?tpc=1&chave=31062002251944463000142000000000056526102354211157", n.qr_url
  end

  def test_provider_falls_back_to_matching_issuer
    p = real.prestador
    assert_equal "51.944.463/0001-42", p.documento
    assert_equal "ACERVO TECH INOVA SIMPLES (I.S.)", p.nome
    assert_equal "Belo Horizonte / MG", p.municipio
    assert_equal "3106200 / 30.140-138", p.codigo_ibge_cep
    assert_includes p.endereco, "RUA TOME DE SOUZA, 1178"
  end

  def test_absent_customer
    assert_nil real.tomador
  end

  def test_service
    n = real
    assert_equal "01.05.01 / 001", n.codigo_tributacao
    assert_equal "1.1103.22.00", n.nbs
    assert_equal "Belo Horizonte / MG / BR", n.local_prestacao
    assert_equal "Teste DanfseJob (homologacao)", n.descricao_servico
  end

  def test_simple_regime_without_tax_base_displays_dash
    n = real
    assert_equal "-", n.bc_issqn
    assert_equal "-", n.issqn_apurado
    assert_equal "R$ 1,00", n.valor_servico
    assert_equal "R$ 1,00", n.valor_liquido
  end

  def test_flattened_rtc_ibscbs
    assert_equal "000 / 000001", real.cst_cclasstrib
    assert_equal "R$ 0,01", real.valor_cbs
  end

  def test_layout_100_without_ibscbs
    n = Danfse::Nfse.new(fixture("leiaute_100.xml"))
    assert_equal "-", n.cst_cclasstrib
    assert_equal "-", n.finalidade
  end

  def test_retained_pis_cofins_nt_102_rule
    n = Danfse::Nfse.new(fixture("retencoes.xml"))
    assert_equal "R$ 0,00", n.pis_proprio
    assert_equal "R$ 0,00", n.cofins_proprio
    assert_equal "R$ 6,66", n.contribuicoes_retidas
    refute_equal n.irrf, n.cp_retida
  end

  def test_rental_without_issqn_incidence
    n = invoice("locacao_nao_incidencia")
    refute n.issqn_incide?
    assert_equal "99.01.01", n.codigo_tributacao
    assert_equal "1.1102.40.00", n.nbs
  end

  def test_complementary_information_and_approximate_taxes
    n = Danfse::Nfse.new(fixture("substituicao.xml"))
    assert n.informacoes_complementares.any? { |item| item.start_with?("NFS-e Subst.: ") }
    assert_equal "Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Federais: -; Estaduais: -; Municipais: -", real.totais_tributos
    assert_equal "Total Simples Nacional: 6,00%", real.informacoes_complementares.last
  end

  def test_customer_issuer_does_not_leak_into_provider
    n = Danfse::Nfse.new(fixture("emitido_pelo_tomador.xml"))
    assert_equal "-", n.prestador.nome
    assert_equal "-", n.prestador.endereco
    assert_equal "Tomador", n.emitente
  end

  def test_foreign_customer
    t = Danfse::Nfse.new(fixture("tomador_exterior.xml")).tomador
    refute_includes t.municipio, " / MG"
    assert_match(%r{\A- / }, t.codigo_ibge_cep)
  end

  def test_recipient_identity_and_issqn_incidence
    real_n = real
    refute real_n.destinatario_proprio_tomador?
    refute Danfse::Nfse.new(fixture("leiaute_100.xml")).destinatario_proprio_tomador?
    assert Danfse::Nfse.new(fixture("com_tomador_pj.xml")).destinatario_proprio_tomador?
    assert real_n.issqn_incide?
  end

  def test_own_pis_cofins_line_hidden_in_2027
    assert real.mostrar_pis_cofins_proprio?
    refute Danfse::Nfse.new(fixture("competencia_2027.xml")).mostrar_pis_cofins_proprio?
  end

  def test_mei_status
    assert_match(/MEI/, Danfse::Nfse.new(fixture("mei.xml")).situacao_nfse)
  end

  def test_invalid_xml
    assert_raises(Danfse::InvalidXml) { Danfse::Nfse.new("<nada/>") }
    assert_raises(Danfse::InvalidXml) { Danfse::Nfse.new("não é xml") }
  end

  def invoice(name)
    Danfse::Nfse.new(fixture("#{name}.xml"))
  end

  def changed(name = "retencoes")
    doc = Nokogiri::XML(fixture("#{name}.xml"))
    doc.remove_namespaces!
    yield doc
    Danfse::Nfse.new(doc.to_xml)
  end

  def test_all_identification_and_header_fields
    n = real
    assert_equal "20/10/2026 18:54:54", n.emissao_dps
    assert_equal "NFS-e Gerada", n.situacao_nfse
    assert_equal "NFS-e regular", n.finalidade
    assert_equal "Município: Belo Horizonte / MG", n.municipio_cabecalho
    assert_equal "Ambiente Gerador: Sistema Nacional da NFS-e", n.ambiente_gerador
    assert_equal "Tipo de Ambiente: Homologação", n.tipo_ambiente
    assert_equal "565 / 31062002251944463000142000000000056526102354211157", n.canhoto_numero_chave
    assert_nil invoice("locacao_nao_incidencia").municipio_cabecalho
    assert_equal "Optante - Microempresa ou Empresa de ...", n.prestador_simples
    assert_equal "Regime de apuração dos tributos federais e municipal pelo SN", n.prestador_regime_sn
  end

  def test_domestic_customer_fields
    t = invoice("com_tomador_pj").tomador
    assert_instance_of Danfse::Nfse::Pessoa, t
    assert_equal "11.444.777/0001-61", t.documento
    assert_equal "654321", t.inscricao_municipal
    assert_equal "3133334444", t.telefone
    assert_equal "Cliente Exemplo Ltda", t.nome
    assert_equal "São Paulo / SP", t.municipio
    assert_equal "3550308 / 01.001-000", t.codigo_ibge_cep
    assert_equal "Rua Modelo, 200, Sala 3, Centro", t.endereco
    assert_equal "cliente@example.com", t.email
  end

  def test_individual_customer_distinct_recipient_and_intermediary
    n = invoice("com_tomador_pf_destinatario_intermediario")
    assert_equal "123.456.789-09", n.tomador.documento
    assert_equal "Pessoa Exemplo", n.tomador.nome
    assert_equal "11.444.777/0001-61", n.destinatario.documento
    assert_equal "Destinatário Exemplo Ltda", n.destinatario.nome
    assert_equal "12.345.678/0001-95", n.intermediario.documento
    assert_equal "Curitiba / PR", n.intermediario.municipio
    assert_equal "987654", n.intermediario.inscricao_municipal
    assert_equal "4132225555", n.intermediario.telefone
    assert_equal "Intermediário Exemplo Ltda", n.intermediario.nome
    refute n.destinatario_proprio_tomador?
    n = changed("com_tomador_pf_destinatario_intermediario") { |doc| doc.at_xpath("//infDPS/IBSCBS/indDest").content = "0" }
    refute n.destinatario_proprio_tomador?
    assert_nil real.destinatario
    assert_nil real.intermediario
  end

  def test_foreign_document_and_address
    t = invoice("tomador_exterior").tomador
    assert_equal "US-EXAMPLE-123", t.documento
    assert_equal "New York / NY", t.municipio
    assert_equal "- / 10001", t.codigo_ibge_cep
    assert_equal "Example Street, 10", t.endereco
    assert_equal "Dispensado do NIF", invoice("tomador_exterior_sem_nif").tomador.documento
    {"0" => "Não informado na nota de origem", "2" => "Não exigência do NIF", "9" => "-"}.each do |code, expected|
      n = changed("tomador_exterior_sem_nif") { |doc| doc.at_xpath("//toma/cNaoNIF").content = code }
      assert_equal expected, n.tomador.documento
    end
  end

  def test_provider_address_fallback_uses_whole_group_only_for_matching_documents
    n = changed("com_tomador_pj") do |doc|
      doc.at_xpath("//prest").add_child("<xNome>Nome declarado</xNome><fone>  </fone><end><endNac><cMun>3550308</cMun></endNac><xLgr>Rua declarada</xLgr></end>")
      doc.at_xpath("//emit").add_child("<fone>3133335555</fone><email>loja@example.com</email>")
    end
    assert_equal "Nome declarado", n.prestador.nome
    assert_equal "3133335555", n.prestador.telefone
    assert_equal "loja@example.com", n.prestador.email
    assert_equal "São Paulo / SP", n.prestador.municipio
    assert_equal "3550308 / -", n.prestador.codigo_ibge_cep
    assert_equal "Rua declarada", n.prestador.endereco
    n = changed("emitido_pelo_tomador") { |doc| doc.at_xpath("//infDPS/tpEmit").content = "3" }
    assert_equal "Intermediário", n.emitente
    assert_equal "-", n.prestador.nome
    assert_equal "-", n.prestador.codigo_ibge_cep
    n = changed("com_tomador_pj") do |doc|
      doc.xpath("//emit/CNPJ | //prest/CNPJ").each { |node| node.name = "CPF"; node.content = "12345678909" }
    end
    assert_equal "Loja Exemplo Ltda", n.prestador.nome
    n = changed("com_tomador_pj") { |doc| doc.xpath("//emit/CNPJ | //prest/CNPJ").remove }
    assert_equal "-", n.prestador.nome
  end

  def test_long_and_escaped_service_description
    n = invoice("descricao_longa")
    assert_equal 1300, n.descricao_servico.length
    assert n.descricao_servico.end_with?("...")
    assert_includes n.descricao_servico, "Ação & \"exemplo\" 😀"
    assert_equal "Licenciamento ou cessão de direito de uso de programas de computação", n.descricao_tributacao
    n = changed { |doc| doc.at_xpath("//xTribMun").content = "  "; doc.at_xpath("//xTribNac").content = "á" * 168 }
    assert_equal ("á" * 167) + "...", n.descricao_tributacao
  end

  def test_alternate_xml_paths_and_precedence
    n = changed do |doc|
      dps = doc.at_xpath("//infDPS")
      dps.at_xpath("finNFSe").remove
      dps.at_xpath("IBSCBS").add_child("<finNFSe>0</finNFSe>")
      trib = dps.at_xpath("IBSCBS/valores/trib")
      trib.add_child("<gIBSCBS><CST>123</CST><cClassTrib>456789</cClassTrib></gIBSCBS>")
      doc.at_xpath("//infNFSe").add_child("<xOutInf>Primeiro</xOutInf>")
      doc.at_xpath("//infNFSe/valores").add_child("<xOutInf>Segundo</xOutInf>")
    end
    assert_equal "NFS-e regular", n.finalidade
    assert_equal "123 / 456789", n.cst_cclasstrib
    assert_includes n.informacoes_complementares, "Inf. A. T. Mun.: Primeiro"
    refute_includes n.informacoes_complementares, "Inf. A. T. Mun.: Segundo"
    n = changed { |doc| doc.at_xpath("//infDPS/IBSCBS").add_child("<finNFSe>9</finNFSe>") }
    assert_equal "NFS-e regular", n.finalidade
    assert_includes invoice("leiaute_100").informacoes_complementares, "Inf. A. T. Mun.: Informação municipal antiga"
  end

  def test_issqn_values_and_optional_rows
    n = invoice("retencoes")
    {tributacao_issqn: "Operação tributável", local_incidencia_issqn: "Belo Horizonte / MG / BR", regime_especial: "Nenhum", tipo_imunidade: "-", suspensao: "-", processo_suspensao: "-", beneficio_municipal: "Redução da BC", calculo_bm: "R$ 1,23", deducoes: "R$ 5,79", desconto_incondicionado: "R$ 0,11", bc_issqn: "R$ 87,65", aliquota_aplicada: "2,50%", retencao_issqn: "Retido pelo Tomador", issqn_apurado: "R$ 2,19"}.each do |method, expected|
      assert_equal expected, n.public_send(method), method
    end
    refute n.linha_regime_vazia?
    refute n.linha_beneficio_vazia?
    refute real.linha_regime_vazia?
    assert real.linha_beneficio_vazia?
    n = changed do |doc|
      doc.at_xpath("//infNFSe/valores/vCalcBM").remove
      doc.at_xpath("//tribMun").add_child("<BM><vRedBCBM>7.89</vRedBCBM></BM>")
      doc.at_xpath("//infDPS/valores").add_child("<vDedRed><vDR>8.76</vDR></vDedRed>")
    end
    assert_equal "R$ 7,89", n.calculo_bm
    assert_equal "R$ 8,76", n.deducoes
    n = changed { |doc| doc.xpath("//tribMun | //prest/regTrib").remove }
    assert n.issqn_incide?
    assert n.linha_regime_vazia?
    assert_equal "-", n.tributacao_issqn
    n = changed { |doc| doc.at_xpath("//tribMun").add_child("<cPaisResult>US</cPaisResult>") }
    assert_equal "Belo Horizonte / MG / US", n.local_incidencia_issqn
  end

  def test_layout_version_controls_issqn_and_benefit_descriptions
    n = changed("leiaute_100") do |doc|
      doc.at_xpath("//tribISSQN").content = "3"
      doc.at_xpath("//infNFSe/valores").add_child("<tpBM>1</tpBM>")
    end
    refute n.issqn_incide?
    assert_equal "Não Incidência", n.tributacao_issqn
    assert_equal "Alíquota Diferenciada", n.beneficio_municipal
    n = changed("leiaute_100") { |doc| doc.at_xpath("//tribISSQN").content = "4" }
    assert n.issqn_incide?
    assert_equal "Imunidade", n.tributacao_issqn
  end

  def test_federal_retention_only_applies_to_code_one
    n = invoice("retencoes")
    assert_equal "R$ 4,44", n.irrf
    assert_equal "R$ 5,55", n.cp_retida
    assert_equal "PIS/COFINS Retidos", n.descricao_contribuicoes_retidas
    %w[0 2 3 4 5 6 7 8 9].each do |code|
      n = changed { |doc| doc.at_xpath("//tpRetPisCofins").content = code }
      assert_equal "R$ 1,11", n.contribuicoes_retidas
      assert_equal "R$ 2,22", n.pis_proprio
      assert_equal "R$ 3,33", n.cofins_proprio
    end
    n = changed { |doc| doc.xpath("//tribFed").remove }
    assert_equal "-", n.contribuicoes_retidas
    assert_equal "-", n.pis_proprio
    n = changed { |doc| doc.at_xpath("//dCompet").content = "2026-12-31" }
    assert n.mostrar_pis_cofins_proprio?
    n = changed { |doc| doc.at_xpath("//dCompet").content = "2027-01-01" }
    refute n.mostrar_pis_cofins_proprio?
  end

  def test_ibscbs_and_totals
    n = invoice("retencoes")
    {indicador_operacao: "030101 / 3106200 / Belo Horizonte / MG", exclusoes_reducoes: "R$ 11,30", bc_ibscbs: "R$ 0,96", red_aliquotas: "10,00% / 20,00% / 30,00%", aliquotas_ibs: "0,10% / 0,00%", aliq_efetiva_mun: "0,00%", valor_ibs_mun: "R$ 0,00", aliq_efetiva_uf: "0,10%", valor_ibs_uf: "R$ 0,00", valor_ibs_total: "R$ 0,00", aliquota_cbs: "0,90%", aliq_efetiva_cbs: "0,90%", valor_cbs: "R$ 0,01", valor_servico: "R$ 94,78", desconto_incondicionado_total: "R$ 0,11", desconto_condicionado: "R$ 0,22", total_retencoes: "R$ 18,84", valor_liquido: "R$ 75,61", total_ibscbs: "R$ 0,01", valor_liquido_ibscbs: "R$ 75,62"}.each do |method, expected|
      assert_equal expected, n.public_send(method), method
    end
    assert_equal "R$ 0,04", real.exclusoes_reducoes
    n = changed { |doc| doc.xpath("//vDescIncond | //vCalcReeRepRes | //vISSQN | //vPis | //vCofins | //vCalcDR").remove }
    assert_equal "-", n.exclusoes_reducoes
    assert_equal "-", n.deducoes
    n = changed { |doc| doc.xpath("//vDescIncond | //vCalcReeRepRes | //vISSQN | //vPis | //vCofins").each { |node| node.content = "0.001" } }
    assert_equal "R$ 0,01", n.exclusoes_reducoes
    n = changed("leiaute_100") { |doc| doc.xpath("//tribFed").remove }
    assert_equal "-", n.total_ibscbs
    assert_equal "-", n.bc_ibscbs
  end

  def test_complementary_information_order
    n = invoice("substituicao")
    assert_equal ["Inf. Cont.: Contrato de exemplo", "NFS-e Subst.: 31062002112223330001810000000000056426102354211157", "Doc. Ref.: DOC-123", "Cod. Obra: OBRA-123", "Insc. Imob.: IMOVEL-123", "Cod. Evt.: EVENTO-123", "Doc. Tec.: TEC-123", "Núm. Ped.: PED-123", "Item Ped.: Item de exemplo", "Inf. A. T. Mun.: Informação municipal de exemplo", "Total Simples Nacional: 6,00%"], n.informacoes_complementares
  end

  def test_approximate_taxes_in_money_or_percentage_and_disabled
    n = changed do |doc|
      doc.at_xpath("//totTrib").children.remove
      doc.at_xpath("//totTrib").add_child("<vTotTrib><vTotTribFed>1.23</vTotTribFed><vTotTribEst>2.34</vTotTribEst><vTotTribMun>3.45</vTotTribMun></vTotTrib>")
    end
    assert_equal "Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Federais: R$ 1,23; Estaduais: R$ 2,34; Municipais: R$ 3,45", n.totais_tributos
    n = changed do |doc|
      doc.at_xpath("//totTrib").children.remove
      doc.at_xpath("//totTrib").add_child("<pTotTrib><pTotTribFed>1.23</pTotTribFed><pTotTribEst>2.34</pTotTribEst></pTotTrib>")
    end
    assert_equal "Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Federais: 1,23%; Estaduais: 2,34%; Municipais: -", n.totais_tributos
    n = changed do |doc|
      doc.at_xpath("//totTrib").children.remove
      doc.at_xpath("//totTrib").add_child("<indTotTrib>0</indTotTrib><vTotTrib><vTotTribFed>9.99</vTotTribFed></vTotTrib>")
    end
    assert_equal "Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Federais: -; Estaduais: -; Municipais: -", n.totais_tributos
  end

  def test_missing_fields_whitespace_and_unknown_status
    n = Danfse::Nfse.new("<NFSe versao=\"1.01\"><infNFSe Id=\"NFS123\"><nNFSe>   </nNFSe><DPS><infDPS><prest/></infDPS></DPS></infNFSe></NFSe>")
    %i[numero competencia emissao_nfse emissao_dps finalidade descricao_servico bc_issqn issqn_apurado cst_cclasstrib local_prestacao local_incidencia_issqn indicador_operacao red_aliquotas aliquotas_ibs].each do |method|
      assert_equal "-", n.public_send(method), method
    end
    assert_equal "-", n.prestador.nome
    assert_equal "-", n.prestador.endereco
    assert n.issqn_incide?
    n = changed { |doc| doc.at_xpath("//cStat").content = "  999  "; doc.at_xpath("//xTribMun").content = "  " }
    assert_equal "999", n.situacao_nfse
    assert_equal "Licenciamento ou cessão de direito de uso de programas de computação.", n.descricao_tributacao
    n = changed { |doc| doc.at_xpath("//cLocPrestacao").replace("<cPaisPrestacao>US</cPaisPrestacao>") }
    assert_equal "- / - / US", n.local_prestacao
  end

  def test_invalid_xml_missing_or_blank_id_and_malformed_document
    ["<NFSe><infNFSe/></NFSe>", "<NFSe><infNFSe Id=\"  \"/></NFSe>", "<NFSe><infNFSe Id=\"NFS123\"></NFSe>"].each do |xml|
      assert_raises(Danfse::InvalidXml) { Danfse::Nfse.new(xml) }
    end
  end

  def test_zero_values_are_present_and_total_ibscbs_includes_both_taxes
    n = changed do |doc|
      doc.at_xpath("//vIBSTot").content = "1.23"
      doc.at_xpath("//vCBS").content = "2.34"
      doc.at_xpath("//infDPS/valores").add_child("<vDedRed><vDR>0.00</vDR></vDedRed>")
      doc.at_xpath("//infNFSe/valores/vCalcBM").content = "0.00"
    end
    assert_equal "R$ 3,57", n.total_ibscbs
    assert_equal "R$ 0,00", n.deducoes
    assert_equal "R$ 0,00", n.calculo_bm
    n = changed do |doc|
      doc.xpath("//vDescIncond | //vCalcReeRepRes | //vISSQN | //vPis | //vCofins").each { |node| node.content = "0.00" }
    end
    assert_equal "R$ 0,00", n.exclusoes_reducoes
  end

  def test_blank_primary_paths_allow_alternative_values
    n = changed do |doc|
      doc.at_xpath("//infDPS/finNFSe").content = "  "
      doc.at_xpath("//infDPS/IBSCBS").add_child("<finNFSe>0</finNFSe>")
      doc.at_xpath("//infDPS/IBSCBS/valores/trib").add_child("<gIBSCBS><CST> </CST><cClassTrib> </cClassTrib></gIBSCBS>")
      doc.at_xpath("//infNFSe").add_child("<xOutInf> </xOutInf>")
      doc.at_xpath("//infNFSe/valores").add_child("<xOutInf> Alternativa </xOutInf>")
    end
    assert_equal "NFS-e regular", n.finalidade
    assert_equal "000 / 000001", n.cst_cclasstrib
    assert_includes n.informacoes_complementares, "Inf. A. T. Mun.: Alternativa"
  end

  def test_layout_100_benefit_at_dps_path_and_unknown_raw_text
    n = changed("leiaute_100") do |doc|
      doc.at_xpath("//tribMun").add_child("<BM><tpBM>2</tpBM><vRedBCBM>0.00</vRedBCBM></BM>")
    end
    assert_equal "Redução da BC", n.beneficio_municipal
    assert_equal "R$ 0,00", n.calculo_bm
    refute n.linha_beneficio_vazia?
    n = changed("leiaute_100") do |doc|
      doc.at_xpath("//tribMun").add_child("<BM><tpBM> Benefício legado </tpBM></BM>")
    end
    assert_equal "Benefício legado", n.beneficio_municipal
  end

  def test_partial_groups_preserve_placeholders_and_unknown_municipalities
    n = changed do |doc|
      doc.at_xpath("//infDPS/IBSCBS/valores/trib/cClassTrib").remove
      doc.at_xpath("//infNFSe/IBSCBS/cLocalidadeIncid").content = "9999999"
      doc.at_xpath("//infNFSe/IBSCBS/valores/mun/pRedAliqMun").remove
      doc.at_xpath("//infDPS/tpAmb").content = "1"
      doc.at_xpath("//infDPS/dCompet").remove
    end
    assert_equal "000 / -", n.cst_cclasstrib
    assert_equal "030101 / 9999999 / Belo Horizonte / -", n.indicador_operacao
    assert_equal "10,00% / - / 30,00%", n.red_aliquotas
    assert_equal "Tipo de Ambiente: Produção", n.tipo_ambiente
    refute n.homologacao?
    refute n.mostrar_pis_cofins_proprio?
  end

  def test_repeated_complementary_items_keep_order_and_do_not_truncate_approximate_taxes
    n = changed("substituicao") do |doc|
      doc.at_xpath("//gItemPed").add_child("<xItemPed>Outro item</xItemPed>")
      doc.at_xpath("//xInfComp").content = "á" * 100
    end
    assert_includes n.informacoes_complementares, "Item Ped.: Item de exemplo"
    assert_includes n.informacoes_complementares, "Item Ped.: Outro item"
    assert_equal "Total Simples Nacional: 6,00%", n.informacoes_complementares.last
    assert_equal "Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Federais: -; Estaduais: -; Municipais: -", n.totais_tributos
  end

  def test_long_complementary_information_respects_limit_and_keeps_simples_total
    n = changed("substituicao") { |doc| doc.at_xpath("//xInfComp").content = "á" * 2100 }
    items = n.informacoes_complementares
    assert_equal 2000, items.join(" | ").length
    assert items.first.start_with?("Inf. Cont.: ")
    assert items.first.end_with?("...")
    assert_equal "Total Simples Nacional: 6,00%", items.last
    assert_equal "Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Federais: -; Estaduais: -; Municipais: -", n.totais_tributos
    n = changed("substituicao") do |doc|
      doc.at_xpath("//pTotTribSN").remove
      doc.at_xpath("//xInfComp").content = "á" * 2100
    end
    assert_equal 2000, n.informacoes_complementares.join(" | ").length
    assert n.informacoes_complementares.last.end_with?("...")
  end

  def test_customer_is_not_recipient_with_indicator_one_without_dest
    n = changed("com_tomador_pj") { |doc| doc.at_xpath("//infDPS/IBSCBS/indDest").content = "1" }
    refute_nil n.tomador
    assert_nil n.destinatario
    refute n.destinatario_proprio_tomador?
  end

  def test_complementary_legacy_property_and_event_paths
    %w[leiaute_100 com_tomador_pj].each do |name|
      n = changed(name) do |doc|
        doc.at_xpath("//serv").add_child("<obra><inscImobFisc>LEGADO-123</inscImobFisc><cObra>OBRA-123</cObra></obra><atvEvento><id>EVENTO-100</id></atvEvento>")
      end
      assert_includes n.informacoes_complementares, "Insc. Imob.: LEGADO-123"
      assert_includes n.informacoes_complementares, "Cod. Evt.: EVENTO-100"
    end
    n = changed("substituicao") do |doc|
      doc.at_xpath("//obra").add_child("<inscImobFisc>OUTRO</inscImobFisc>")
      doc.at_xpath("//atvEvento").add_child("<id>OUTRO</id>")
    end
    assert_includes n.informacoes_complementares, "Insc. Imob.: IMOVEL-123"
    assert_includes n.informacoes_complementares, "Cod. Evt.: EVENTO-123"
    refute_includes n.informacoes_complementares, "Insc. Imob.: OUTRO"
    refute_includes n.informacoes_complementares, "Cod. Evt.: OUTRO"
  end

  def test_provider_existing_empty_address_does_not_use_issuer_address
    n = changed("com_tomador_pj") { |doc| doc.at_xpath("//prest").add_child("<end/>") }
    assert_equal "-", n.prestador.endereco
    assert_equal "-", n.prestador.municipio
    assert_equal "-", n.prestador.codigo_ibge_cep
  end

  def test_derived_fixtures_follow_dps_group_order
    Dir[Danfse::ROOT.join("test/fixtures/*.xml")].sort.each do |path|
      doc = Nokogiri::XML(File.read(path)) { |config| config.strict.nonet }
      doc.remove_namespaces!
      order = %w[cLocEmi subst prest toma interm serv valores IBSCBS]
      groups = doc.at_xpath("//infDPS").element_children.map(&:name).select { |name| order.include?(name) }
      assert_equal order.select { |name| groups.include?(name) }, groups, File.basename(path)
    end
  end

  def test_retention_fixture_amounts_are_consistent
    doc = Nokogiri::XML(fixture("retencoes.xml"))
    doc.remove_namespaces!
    amount = ->(path) { BigDecimal(doc.at_xpath(path).text) }
    retained = %w[vRetCSLL vPis vCofins vRetIRRF vRetCP vISSQN].sum(BigDecimal("0")) { |tag| amount.call("//#{tag}") }
    assert_equal retained, amount.call("//vTotalRet")
    assert_equal amount.call("//vServ") - retained - amount.call("//vDescIncond") - amount.call("//vDescCond"), amount.call("//vLiq")
    assert_equal BigDecimal("87.65"), amount.call("//infNFSe/valores/vBC")
    assert_equal BigDecimal("94.78"), amount.call("//vServ")
    base = amount.call("//vServ") - amount.call("//vDescIncond") - amount.call("//vCalcDR") - amount.call("//vCalcReeRepRes") - amount.call("//vCalcBM")
    assert_equal base, amount.call("//infNFSe/valores/vBC")
    assert_equal (base * amount.call("//pAliqAplic") / 100).round(2), amount.call("//vISSQN")
    assert_empty doc.xpath("//tribMun/tpImunidade | //tribMun/exigSusp")
  end
  def test_immunity_and_suspension_are_read_when_present
    n = changed do |doc|
      doc.at_xpath("//tribMun/tribISSQN").content = "2"
      doc.at_xpath("//tribMun").add_child("<tpImunidade>4</tpImunidade><exigSusp><tpSusp>1</tpSusp><nProcesso>PROC-123</nProcesso></exigSusp>")
    end
    assert_equal "Livros, jornais, periódicos e o papel...", n.tipo_imunidade
    assert_equal "Exigibilidade Suspensa por Decisão Ju...", n.suspensao
    assert_equal "PROC-123", n.processo_suspensao
  end
  def test_added_fixture_groups_follow_schema_structure
    doc = Nokogiri::XML(fixture("substituicao.xml"))
    doc.remove_namespaces!
    {
      "//subst" => %w[chSubstda cMotivo xMotivo],
      "//atvEvento" => %w[xNome dtIni dtFim idAtvEvt],
      "//infoCompl" => %w[idDocTec docRef xPed gItemPed xInfComp],
      "//serv" => %w[locPrest cServ obra atvEvento infoCompl],
      "//imovel" => %w[inscImobFisc cCIB],
    }.each do |path, names|
      assert_equal names, doc.at_xpath(path).element_children.map(&:name), path
    end
    names = doc.at_xpath("//infNFSe").element_children.map(&:name)
    assert_operator names.index("valores"), :<, names.index("xOutInf")
    assert_operator names.index("xOutInf"), :<, names.index("IBSCBS")
    assert_operator names.index("IBSCBS"), :<, names.index("DPS")
    Dir[Danfse::ROOT.join("test/fixtures/*.xml")].each do |path|
      doc = Nokogiri::XML(File.read(path))
      doc.remove_namespaces!
      doc.xpath("//toma | //interm | //dest").each do |person|
        order = %w[CNPJ CPF NIF cNaoNIF CAEPF IM xNome end fone email]
        names = person.element_children.map(&:name)
        assert_equal order.select { |name| names.include?(name) }, names, File.basename(path)
      end
    end
  end
  def test_real_rental_customer_and_service
    n = Danfse::Nfse.new(fixture("real/locacao_homologacao_rtc.xml"))
    assert_equal "123.456.789-09", n.tomador.documento
    assert_equal "Cliente Exemplo", n.tomador.nome
    assert_equal "99.01.01", n.codigo_tributacao
    assert_equal "1.1102.40.00", n.nbs
    refute n.issqn_incide?
    assert_equal "Serviços sem a incidência de ISSQN e ICMS", n.descricao_tributacao
    assert_equal "R$ 45,00", n.valor_servico
  end

  def test_derived_rental_uses_real_tax_description
    n = Danfse::Nfse.new(fixture("locacao_nao_incidencia.xml"))
    assert_equal "Serviços sem a incidência de ISSQN e ICMS", n.descricao_tributacao
  end

  def test_malformed_competence_raises_invalid_xml
    xml = fixture("real/acervo_homologacao_rtc.xml").sub(/<dCompet>.*?<\/dCompet>/, "<dCompet>2026-99-40</dCompet>")
    n = Danfse::Nfse.new(xml)
    assert_raises(Danfse::InvalidXml) { n.competencia }
    assert_raises(Danfse::InvalidXml) { n.mostrar_pis_cofins_proprio? }
    assert_raises(Danfse::InvalidXml) { Danfse.render(xml) }
  end

end
