require "test_helper"
require "nokogiri"

class TablesTest < Minitest::Test
  XSD_TYPES = {
    tp_emit: "TSEmitenteDPS",
    c_stat: "TStat",
    fin_nfse: "TSRTCFinNFSe",
    op_simp_nac: "TSOpSimpNac",
    reg_ap_trib_sn: "TSRegimeApuracaoSimpNac",
    reg_esp_trib: "TSRegEspTrib",
    trib_issqn: "TSTribISSQN",
    tp_imunidade: "TSTipoImunidadeISSQN",
    tp_susp: "TSOpExigSuspensa",
    tp_ret_issqn: "TSTipoRetISSQN",
    tp_ret_pis_cofins: "TSTipoRetPISCofins",
    tp_bm: "TBMISSQN",
    amb_ger: "TSAmbGeradorNFSe",
    tp_amb: "TSTipoAmbiente",
  }.freeze

  def test_tp_emit_descriptions
    expected = {
      "1" => "Prestador",
      "2" => "Tomador",
      "3" => "Intermediário",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:tp_emit, code)
    end
  end

  def test_c_stat_descriptions
    expected = {
      "100" => "NFS-e Gerada",
      "102" => "NFS-e de Decisão Judicial",
      "103" => "NFS-e Avulsa",
      "107" => "NFS-e MEI",
      "101" => "NFS-e de Substituição Gerada",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:c_stat, code)
    end
  end

  def test_fin_nfse_descriptions
    expected = {
      "0" => "NFS-e regular",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:fin_nfse, code)
    end
  end

  def test_op_simp_nac_descriptions
    expected = {
      "1" => "Não Optante",
      "2" => "Optante - Microempreendedor Individual (MEI)",
      "3" => "Optante - Microempresa ou Empresa de Pequeno Porte (ME/EPP)",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:op_simp_nac, code)
    end
  end

  def test_reg_ap_trib_sn_descriptions
    expected = {
      "1" => "Regime de apuração dos tributos federais e municipal pelo SN",
      "2" => "Regime de apuração dos tributos federais pelo SN e ISSQN  por fora do SN conforme respectiva legislação municipal do tributo",
      "3" => "Regime de apuração dos tributos federais e municipal por fora do SN conforme respectivas legislações federal e municipal de cada tributo",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:reg_ap_trib_sn, code)
    end
  end

  def test_reg_esp_trib_descriptions
    expected = {
      "0" => "Nenhum",
      "1" => "Ato Cooperado (Cooperativa)",
      "2" => "Estimativa",
      "3" => "Microempresa Municipal",
      "4" => "Notário ou Registrador",
      "5" => "Profissional Autônomo",
      "6" => "Sociedade de Profissionais",
      "9" => "Outros",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:reg_esp_trib, code)
    end
  end

  def test_trib_issqn_descriptions
    expected = {
      "1" => "Operação tributável",
      "2" => "Imunidade",
      "3" => "Exportação de serviço",
      "4" => "Não Incidência",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:trib_issqn, code)
    end
  end

  def test_version_specific_descriptions
    assert_equal "Exportação de serviço", Danfse::Tables.descricao(:trib_issqn, "2", versao: "1.00")
    assert_equal "Imunidade", Danfse::Tables.descricao(:trib_issqn, "2", versao: "1.01")
    assert_equal "Não Incidência", Danfse::Tables.descricao(:trib_issqn, "3", versao: "1.00")
    assert_equal "Exportação de serviço", Danfse::Tables.descricao(:trib_issqn, "3", versao: "1.01")
    assert_equal "Imunidade", Danfse::Tables.descricao(:trib_issqn, "4", versao: "1.00")
    assert_equal "Não Incidência", Danfse::Tables.descricao(:trib_issqn, "4", versao: "1.01")

    assert_equal "Alíquota Diferenciada", Danfse::Tables.descricao(:tp_bm, "1", versao: "1.00")
    assert_equal "Isenção", Danfse::Tables.descricao(:tp_bm, "1", versao: "1.01")
    assert_equal "Redução da BC", Danfse::Tables.descricao(:tp_bm, "2", versao: "1.00")
    assert_equal "Redução da BC em 'ppBM' %", Danfse::Tables.descricao(:tp_bm, "2", versao: "1.01")
    assert_equal "Isenção", Danfse::Tables.descricao(:tp_bm, "3", versao: "1.00")
    assert_equal "Redução da BC em R$ 'vInfoBM'", Danfse::Tables.descricao(:tp_bm, "3", versao: "1.01")
  end

  def test_nao_incidencia_issqn_depends_on_layout_version
    assert Danfse::Tables.nao_incidencia_issqn?("4")
    refute Danfse::Tables.nao_incidencia_issqn?("3")
    assert Danfse::Tables.nao_incidencia_issqn?("3", versao: "1.00")
    refute Danfse::Tables.nao_incidencia_issqn?("4", versao: "1.00")
  end

  def test_tp_imunidade_descriptions
    expected = {
      "0" => "Imunidade (tipo não informado na nota de origem)",
      "1" => "Patrimônio, renda ou serviços, uns dos outros (CF88, Art 150, VI, a)",
      "2" => "Templos de qualquer culto (CF88, Art 150, VI, b)",
      "3" => "Patrimônio, renda ou serviços dos partidos políticos, inclusive suas fundações, das entidades sindicais dos trabalhadores, das instituições de educação e de assistência social, sem fins lucrativos, atendidos os requisitos da lei (CF88, Art 150, VI, c)",
      "4" => "Livros, jornais, periódicos e o papel destinado a sua impressão (CF88, Art 150, VI, d)",
      "5" => "Fonogramas e videofonogramas musicais produzidos no Brasil contendo obras musicais ou literomusicais de autores brasileiros e/ou obras em geral interpretadas por artistas brasileiros bem como os suportes materiais ou arquivos digitais que os contenham, salvo na etapa de replicação industrial de mídias ópticas de leitura a laser.   (CF88, Art 150, VI, e)",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:tp_imunidade, code)
    end
  end

  def test_tp_susp_descriptions
    expected = {
      "1" => "Exigibilidade Suspensa por Decisão Judicial",
      "2" => "Exigibilidade Suspensa por Processo Administrativo",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:tp_susp, code)
    end
  end

  def test_tp_ret_issqn_descriptions
    expected = {
      "1" => "Não Retido",
      "2" => "Retido pelo Tomador",
      "3" => "Retido pelo Intermediario",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:tp_ret_issqn, code)
    end
  end

  def test_tp_ret_pis_cofins_descriptions
    expected = {
      "0" => "PIS/COFINS/CSLL Não Retidos",
      "1" => "PIS/COFINS Retidos",
      "2" => "PIS/COFINS Não Retidos",
      "3" => "PIS/COFINS/CSLL Retidos",
      "4" => "PIS/COFINS Retidos, CSLL Não Retido",
      "5" => "PIS Retido, COFINS/CSLL Não Retido",
      "6" => "COFINS Retido, PIS/CSLL Não Retido",
      "7" => "PIS Não Retido, COFINS/CSLL Retidos",
      "8" => "PIS/COFINS Não Retidos, CSLL Retido",
      "9" => "COFINS Não Retido, PIS/CSLL Retidos",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:tp_ret_pis_cofins, code)
    end
  end

  def test_tp_bm_descriptions
    expected = {
      "1" => "Isenção",
      "2" => "Redução da BC em 'ppBM' %",
      "3" => "Redução da BC em R$ 'vInfoBM'",
      "4" => "Alíquota Diferenciada de 'aliqDifBM' %",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:tp_bm, code)
    end
  end

  def test_amb_ger_descriptions
    expected = {
      "1" => "Prefeitura",
      "2" => "Sistema Nacional da NFS-e",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:amb_ger, code)
    end
  end

  def test_tp_amb_descriptions
    expected = {
      "1" => "Produção",
      "2" => "Homologação",
    }
    expected.each do |code, description|
      assert_equal description, Danfse::Tables.descricao(:tp_amb, code)
    end
  end

  def test_unknown_and_missing_codes
    assert_equal "999", Danfse::Tables.descricao(:c_stat, "999")
    assert_equal "Benefício municipal antigo", Danfse::Tables.descricao(:tp_bm, "Benefício municipal antigo")
    assert_nil Danfse::Tables.descricao(:tp_emit, "9")
    assert_nil Danfse::Tables.descricao(:unknown, "1")
    assert_nil Danfse::Tables.descricao(:c_stat, nil)
    assert_nil Danfse::Tables.descricao(:tp_bm, nil)
  end

  def test_blank_codes_are_missing_for_every_field
    ["", " \t\n"].each do |code|
      Danfse::Tables::TABLES.each_key do |field|
        assert_nil Danfse::Tables.descricao(field, code)
      end
    end
  end

  def test_tables_include_every_code_from_the_101_schema
    tables = Danfse::Tables::TABLES
    assert_equal tables.keys.sort, XSD_TYPES.keys.sort

    schema_path = Danfse::ROOT.join("docs/schemas/1.01/tiposSimples_v1.01.xsd")
    schema = Nokogiri::XML(File.read(schema_path))
    namespaces = { "xs" => "http://www.w3.org/2001/XMLSchema" }

    XSD_TYPES.each do |field, type_name|
      type = schema.at_xpath("//xs:simpleType[@name='#{type_name}']", namespaces)
      refute_nil type, "missing XSD type #{type_name} for #{field}"

      codes = type.xpath(".//xs:enumeration/@value", namespaces).map { |attribute| attribute.value }
      codes.each do |code|
        assert_includes tables.fetch(field).keys, code, "#{field} is missing schema code #{code}"
      end
    end
  end

  def test_tables_cannot_be_mutated
    assert_predicate Danfse::Tables::TABLES, :frozen?
    Danfse::Tables::TABLES.each_value do |table|
      assert_predicate table, :frozen?
      table.each_value { |description| assert_predicate description, :frozen? }
    end
    assert_raises(FrozenError) { Danfse::Tables::TABLES[:tp_emit]["1"] = "Outro" }
    assert_raises(FrozenError) { Danfse::Tables.descricao(:tp_emit, "1").replace("Outro") }
  end
end
