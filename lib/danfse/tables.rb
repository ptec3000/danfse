# frozen_string_literal: true

module Danfse
  module Tables
    TABLES = {
      # TSEmitenteDPS, tiposSimples v1.01.
      tp_emit: {
        "1" => "Prestador",
        "2" => "Tomador",
        "3" => "Intermediário",
      }.freeze,
      # TStat, tiposSimples v1.01; code 101 from TStat v1.00.
      c_stat: {
        "100" => "NFS-e Gerada",
        "101" => "NFS-e de Substituição Gerada",
        "102" => "NFS-e de Decisão Judicial",
        "103" => "NFS-e Avulsa",
        "107" => "NFS-e MEI",
      }.freeze,
      # TSRTCFinNFSe, tiposSimples v1.01.
      fin_nfse: {
        "0" => "NFS-e regular",
      }.freeze,
      # TSOpSimpNac, tiposSimples v1.01.
      op_simp_nac: {
        "1" => "Não Optante",
        "2" => "Optante - Microempreendedor Individual (MEI)",
        "3" => "Optante - Microempresa ou Empresa de Pequeno Porte (ME/EPP)",
      }.freeze,
      # TSRegimeApuracaoSimpNac, tiposSimples v1.01.
      reg_ap_trib_sn: {
        "1" => "Regime de apuração dos tributos federais e municipal pelo SN",
        "2" => "Regime de apuração dos tributos federais pelo SN e ISSQN  por fora do SN conforme respectiva legislação municipal do tributo",
        "3" => "Regime de apuração dos tributos federais e municipal por fora do SN conforme respectivas legislações federal e municipal de cada tributo",
      }.freeze,
      # TSRegEspTrib, tiposSimples v1.01.
      reg_esp_trib: {
        "0" => "Nenhum",
        "1" => "Ato Cooperado (Cooperativa)",
        "2" => "Estimativa",
        "3" => "Microempresa Municipal",
        "4" => "Notário ou Registrador",
        "5" => "Profissional Autônomo",
        "6" => "Sociedade de Profissionais",
        "9" => "Outros",
      }.freeze,
      # TSTribISSQN, tiposSimples v1.01.
      trib_issqn: {
        "1" => "Operação tributável",
        "2" => "Imunidade",
        "3" => "Exportação de serviço",
        "4" => "Não Incidência",
      }.freeze,
      # TSTipoImunidadeISSQN, tiposSimples v1.01.
      tp_imunidade: {
        "0" => "Imunidade (tipo não informado na nota de origem)",
        "1" => "Patrimônio, renda ou serviços, uns dos outros (CF88, Art 150, VI, a)",
        "2" => "Templos de qualquer culto (CF88, Art 150, VI, b)",
        "3" => "Patrimônio, renda ou serviços dos partidos políticos, inclusive suas fundações, das entidades sindicais dos trabalhadores, das instituições de educação e de assistência social, sem fins lucrativos, atendidos os requisitos da lei (CF88, Art 150, VI, c)",
        "4" => "Livros, jornais, periódicos e o papel destinado a sua impressão (CF88, Art 150, VI, d)",
        "5" => "Fonogramas e videofonogramas musicais produzidos no Brasil contendo obras musicais ou literomusicais de autores brasileiros e/ou obras em geral interpretadas por artistas brasileiros bem como os suportes materiais ou arquivos digitais que os contenham, salvo na etapa de replicação industrial de mídias ópticas de leitura a laser.   (CF88, Art 150, VI, e)",
      }.freeze,
      # TSOpExigSuspensa, tiposSimples v1.01.
      tp_susp: {
        "1" => "Exigibilidade Suspensa por Decisão Judicial",
        "2" => "Exigibilidade Suspensa por Processo Administrativo",
      }.freeze,
      # TSTipoRetISSQN, tiposSimples v1.01.
      tp_ret_issqn: {
        "1" => "Não Retido",
        "2" => "Retido pelo Tomador",
        "3" => "Retido pelo Intermediario",
      }.freeze,
      # TSTipoRetPISCofins, tiposSimples v1.01.
      tp_ret_pis_cofins: {
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
      }.freeze,
      # TBMISSQN, tiposSimples v1.01.
      tp_bm: {
        "1" => "Isenção",
        "2" => "Redução da BC em 'ppBM' %",
        "3" => "Redução da BC em R$ 'vInfoBM'",
        "4" => "Alíquota Diferenciada de 'aliqDifBM' %",
      }.freeze,
      # TSAmbGeradorNFSe, tiposSimples v1.01.
      amb_ger: {
        "1" => "Prefeitura",
        "2" => "Sistema Nacional da NFS-e",
      }.freeze,
      # TSTipoAmbiente, tiposSimples v1.01.
      tp_amb: {
        "1" => "Produção",
        "2" => "Homologação",
      }.freeze,
    }.freeze

    OVERRIDES = {
      "1.00" => {
        # TSTribISSQN, tiposSimples v1.00.
        trib_issqn: {
          "1" => "Operação tributável",
          "2" => "Exportação de serviço",
          "3" => "Não Incidência",
          "4" => "Imunidade",
        }.freeze,
        # TSOpTipoBM, tiposSimples v1.00.
        tp_bm: {
          "1" => "Alíquota Diferenciada",
          "2" => "Redução da BC",
          "3" => "Isenção",
        }.freeze,
      }.freeze,
    }.freeze

    RAW_WHEN_UNKNOWN = %i[c_stat tp_bm].freeze

    def self.descricao(field, code, versao: "1.01")
      return nil if code.nil?

      value = code.to_s
      return nil if value.strip.empty?

      table = OVERRIDES.dig(versao.to_s, field) || TABLES[field]
      table&.[](value) || (value if RAW_WHEN_UNKNOWN.include?(field))
    end

    def self.nao_incidencia_issqn?(code, versao: "1.01")
      return false if code.nil?

      expected_code = versao.to_s == "1.00" ? "3" : "4"
      code.to_s == expected_code
    end
  end
end
