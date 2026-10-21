# frozen_string_literal: true

module Danfse
  # NT 008 v1.02, table 2.4.5. Coordinates are centimeters from the page top.
  # Labels follow Annex I, including its capitalization and punctuation.
  module Layout
    def self.cm(value) = value * 72.0 / 2.54

    LEFT = 0.30
    WIDTH = 20.40
    BORDER = 0.15
    BOTTOM = 28.77
    COLLAPSED = 0.32
    LABEL_HEIGHT = 0.40
    SERVICE_LABEL_SIZE = 8
    INSET = 0.10
    VERTICAL_INSET = 0.04
    VALUE_GAP = 1.2 / cm(1)
    TITLE_HEIGHT = 0.63
    TITLE_MIN_SIZE = 7
    LABEL_MIN_SIZE = 6
    TITLE_TEXT_HEIGHT = 0.42
    LABEL_FIT_RATIO = 0.99
    TAX_GAP = 0.35
    IDENTIFICATION_SIZE = 7.5
    MUNICIPALITY_SIZE = 9
    ENVIRONMENT_SIZE = 7
    HEADER_MIN_SIZE = 6
    CONTENT_MIN_SIZE = 7
    AUTHENTICITY_SIZE = 6
    COLLAPSED_SIZE = 8
    SHADE_COLOR = "F2F2F2"
    DIVIDER_WIDTH = 0.5
    FRAME_WIDTH = 1
    FONT_SIZE = 8
    LABEL_SIZE = 7
    TITLE_SIZE = 8.5
    HEADER_SIZE = 9.5
    WATERMARK_SIZE = 60
    WATERMARK_ANGLE = 45
    WATERMARK_CENTER = [10.5, 14.85].freeze
    WATERMARK_BOX = {x: 2.0, y: 13.65, w: 17.0, h: 2.4}.freeze
    AUTHENTICITY = "A autenticidade desta NFS-e pode ser verificada pela leitura deste código QR ou pela consulta da chave de acesso no portal nacional da NFS-e"
    def self.field(label, x, y, w = 5.09, h = 0.63)
      {label: label, h: h, w: w, x: x, y: y}.freeze
    end

    # Rows keep Annex I's columns and order. Taller rows accommodate wrapped
    # labels at the larger Sefin-style sizes, without reducing the value font.
    def self.rows(fields, heights)
      origins = fields.values.map { |field| field[:y] }.uniq.sort
      positions = origins.zip(heights).to_h
      fields.transform_values do |field|
        index = origins.index(field[:y])
        field.merge(y: origins.first + heights.take(index).sum,
          h: positions.fetch(field[:y])).freeze
      end.freeze
    end

    HEADER = {
      background: field(nil, 0.30, 0.30, 20.40, 1.16),
      logo: field(nil, 0.49, 0.44, 4.00, 0.85),
      title: field("DANFSe v2.0\nDocumento Auxiliar da NFS-e", 5.41, 0.30, 10.19, 0.75),
      warning: field("NFS-e SEM VALIDADE JURÍDICA", 5.41, 1.05, 10.19, 0.40),
      municipio_cabecalho: field(nil, 15.62, 0.30, 5.09, 0.64),
      ambiente_gerador: field(nil, 15.62, 0.64, 5.09, 0.57),
      tipo_ambiente: field(nil, 15.62, 1.18, 5.09, 0.30),
      qr: field(nil, 17.48, 1.67, 1.52, 1.52),
      authenticity: field(nil, 15.80, 3.36, 4.87, 0.80),
    }.freeze

    IDENTIFICATION_BASE = {
      chave: field("CHAVE DE ACESSO DA NFS-E", 0.30, 1.48, 15.30, 0.77),
      numero: field("NÚMERO DA NFS-E", 0.30, 2.27, 5.09, 0.67),
      competencia: field("COMPETÊNCIA DA NFS-E", 5.41, 2.27, 5.09, 0.67),
      emissao_nfse: field("DATA E HORA DA EMISSÃO DA NFS-E", 10.51, 2.27, 5.09, 0.67),
      numero_dps: field("NÚMERO DA DPS", 0.30, 2.96, 5.09, 0.67),
      serie_dps: field("SÉRIE DA DPS", 5.41, 2.96, 5.09, 0.67),
      emissao_dps: field("DATA E HORA DA EMISSÃO DA DPS", 10.51, 2.96, 5.09, 0.67),
      emitente: field("EMITENTE DA NFS-e", 0.30, 3.65, 5.09, 0.67),
      situacao_nfse: field("SITUAÇÃO DA NFS-e", 5.41, 3.65, 5.09, 0.67),
      finalidade: field("FINALIDADE", 10.51, 3.65, 5.09, 0.67),
    }.freeze

    # Identification values retain their own line at 8 pt.
    IDENTIFICATION_ROW = 0.75
    IDENTIFICATION = IDENTIFICATION_BASE.transform_values do |field|
      shift = if field[:y] >= 3.65 then 0.16
      elsif field[:y] >= 2.96 then 0.08
      else 0
      end
      field.merge(y: field[:y] + shift, h: [field[:h], IDENTIFICATION_ROW].max).freeze
    end.freeze

    PERSON_TITLES = {
      prestador: "PRESTADOR / FORNECEDOR", tomador: "TOMADOR / ADQUIRENTE",
      destinatario: "DESTINATÁRIO DA OPERAÇÃO", intermediario: "INTERMEDIÁRIO DA OPERAÇÃO",
    }.freeze
    PERSON_MISSING = {
      tomador: "TOMADOR/ADQUIRENTE DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e",
      destinatario: "DESTINATÁRIO DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e",
      intermediario: "INTERMEDIÁRIO DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e",
    }.freeze
    SAME_RECIPIENT = "O DESTINATÁRIO É O PRÓPRIO TOMADOR/ADQUIRENTE DA OPERAÇÃO"
    NO_ISSQN = "TRIBUTAÇÃO MUNICIPAL (ISSQN) - OPERAÇÃO NÃO SUJEITA AO ISSQN"

    # Offsets reproduce the small row-spacing differences in the table.
    PERSON_ORIGINS = {prestador: 4.34, tomador: 6.92, destinatario: 8.86, intermediario: 10.80}.freeze
    PEOPLE = PERSON_ORIGINS.to_h do |role, y|
      third = {prestador: 1.28, tomador: 1.30, destinatario: 1.30, intermediario: 1.29}.fetch(role)
      fields = {
        title: field(PERSON_TITLES.fetch(role), 0.30, y),
        documento: field("CNPJ / CPF / NIF", 5.41, y),
        inscricao_municipal: field("Indicador Municipal (Inscrição)", 10.51, y),
        telefone: field("Telefone", 15.62, y),
        nome: field("Nome / Nome Empresarial", 0.30, y + 0.64, 10.19),
        municipio: field("Município / Sigla UF", 10.51, y + 0.64),
        codigo_ibge_cep: field("Código IBGE / CEP", 15.62, y + 0.64),
        endereco: field("Endereço", 0.30, y + third, 10.19),
        email: field("E-mail", 10.51, y + third, 10.19),
      }
      fields.delete(:inscricao_municipal) if role == :destinatario
      if role == :prestador
        fields[:prestador_simples] = field("Simples Nacional na Data de Competência", 0.30, 6.28)
        # Annex I puts this in column 2; the table puts it in column 3.
        fields[:prestador_regime_sn] = field("Regime de Apuração Tributária pelo SN", 5.41, 6.28, 15.29)
      end
      [role, rows(fields, role == :prestador ? [0.70, 0.70, 0.70, 1.30] : [0.70, 0.70, 0.70])]
    end.freeze

    SERVICE = {
      title: field("SERVIÇO PRESTADO", 0.30, 12.74, 5.09, 0.95),
      codigo_tributacao: field("Código de Tributação Nacional / Municipal", 5.41, 12.74, 5.09, 0.95),
      nbs: field("Código da NBS", 10.51, 12.74, 5.09, 0.95),
      local_prestacao: field("Local da Prestação / Sigla UF / País", 15.62, 12.74, 5.09, 0.95),
      descricao_tributacao: field(nil, 0.30, 13.69, 20.40, 0.45),
      descricao_servico: field("Descrição do Serviço", 0.30, 14.04, 20.40, 0.80),
    }.freeze
    MUNICIPAL = rows({
      title: field("TRIBUTAÇÃO MUNICIPAL (ISSQN)", 0.30, 14.43),
      tributacao_issqn: field("Tipo de Tributação do ISSQN", 5.41, 14.43),
      local_incidencia_issqn: field("Município / Sigla UF / País de Incidência do ISSQN", 10.51, 14.43, 10.19),
      regime_especial: field("Regime Especial de Tributação do ISSQN", 0.30, 15.08),
      tipo_imunidade: field("Tipo de Imunidade do ISSQN", 5.41, 15.08),
      suspensao: field("Suspensão da Exigibilidade do ISSQN", 10.51, 15.08),
      processo_suspensao: field("Número Processo Suspensão", 15.62, 15.08),
      beneficio_municipal: field("Benefício Municipal", 0.30, 15.73),
      calculo_bm: field("Cálculo do BM", 5.41, 15.73),
      deducoes: field("Total Deduções/Reduções", 10.51, 15.73),
      desconto_incondicionado: field("Desconto Incondicionado", 15.62, 15.73),
      bc_issqn: field("BC ISSQN", 0.30, 16.37),
      aliquota_aplicada: field("Alíquota Aplicada", 5.41, 16.37),
      retencao_issqn: field("Retenção do ISSQN", 10.51, 16.37),
      issqn_apurado: field("ISSQN Apurado", 15.62, 16.37),
    }, [0.75, 0.92, 0.75, 0.75])
    REGIME_FIELDS = %i[regime_especial tipo_imunidade suspensao processo_suspensao].freeze
    BENEFIT_FIELDS = %i[beneficio_municipal calculo_bm deducoes desconto_incondicionado].freeze
    REGIME_HEIGHT = 0.92
    BENEFIT_HEIGHT = 0.75
    FEDERAL_OPTIONAL_HEIGHT = 0.80
    FEDERAL = rows({
      title: field("TRIBUTAÇÃO FEDERAL (EXCETO CBS)", 0.30, 17.02),
      irrf: field("IRRF", 5.41, 17.02),
      cp_retida: field("Contribuição Previdenciária - Retida", 10.51, 17.02),
      contribuicoes_retidas: field("Contribuições Sociais – Retidas", 15.62, 17.02),
      pis_proprio: field("PIS - Débito Apuração Própria", 0.30, 17.67),
      cofins_proprio: field("COFINS - Débito Apuração Própria", 5.41, 17.67),
      descricao_contribuicoes_retidas: field("Descrição Contrib. Sociais – Retidas", 10.51, 17.67, 10.19),
    }, [0.80, 0.80])
    IBS = rows({
      title: field("TRIBUTAÇÃO IBS / CBS", 0.30, 18.32),
      cst_cclasstrib: field("CST / cClassTrib", 5.41, 18.32),
      indicador_operacao: field("Indicador de Operação / Código IBGE Incidência / Município Incidência / Sigla UF", 10.51, 18.32, 10.19),
      exclusoes_reducoes: field("Exclusões e Reduções da Base de Cálculo", 0.30, 18.96),
      bc_ibscbs: field("Base de Cálculo Após Exclusões e Reduções", 5.41, 18.96),
      red_aliquotas: field("Red. Alíquota IBS / Red. Alíquota CBS", 10.51, 18.96),
      aliquotas_ibs: field("Alíquota – IBS UF / IBS Mun", 15.62, 18.96),
      aliq_efetiva_mun: field("Alíq. Efetiva Municipal – IBS", 0.30, 19.61),
      valor_ibs_mun: field("Valor Apurado Municipal – IBS", 5.41, 19.61),
      aliq_efetiva_uf: field("Alíq. Efetiva Estadual – IBS", 10.51, 19.61),
      valor_ibs_uf: field("Valor Apurado Estadual – IBS", 15.62, 19.61),
      valor_ibs_total: field("Valor Total Apurado – IBS", 0.30, 20.26),
      aliquota_cbs: field("Alíquota - CBS", 5.41, 20.26),
      aliq_efetiva_cbs: field("Alíquota Efetiva – CBS", 10.51, 20.26),
      valor_cbs: field("Valor Total Apurado – CBS", 15.62, 20.26),
    }, [0.80, 0.95, 0.75, 0.75])
    TOTALS = rows({
      title: field("VALOR TOTAL DA NFS-E", 0.30, 20.90, 5.09, 0.67),
      valor_servico: field("VALOR DA OPERAÇÃO / SERVIÇO", 5.41, 20.90, 5.09, 0.67),
      desconto_incondicionado_total: field("Desconto Incondicionado", 10.51, 20.90, 5.09, 0.67),
      desconto_condicionado: field("Desconto Condicionado", 15.62, 20.90, 5.09, 0.67),
      total_retencoes: field("Total das Retenções (ISSQN / Federais)", 0.30, 21.59, 5.09, 0.67),
      valor_liquido: field("VALOR LÍQUIDO DA NFS-e", 5.41, 21.59, 5.09, 0.67),
      total_ibscbs: field("Total do IBS/CBS", 10.51, 21.59, 5.09, 0.67),
      valor_liquido_ibscbs: field("VALOR LÍQUIDO DA NFS-e + IBS/CBS", 15.62, 21.59, 5.09, 0.67),
    }, [0.75, 0.92])
    COMPLEMENTARY = {
      title: field("INFORMAÇÕES COMPLEMENTARES", 0.30, 22.27, 5.09, 0.70),
      content: field(nil, 0.30, 22.99, 20.40, 1.17),
    }.freeze
    RECEIPT = rows({
      date: field("DATA CIENTIFICAÇÃO:", 0.30, 28.10, 5.09, 0.67),
      signature: field("IDENTIFICAÇÃO E ASSINATURA", 5.41, 28.10, 5.09, 0.67),
      canhoto_numero_chave: field("Nº NFS-e / CHAVE NFS-e", 10.51, 28.10, 10.19, 0.67),
    }, [0.80])
    START_Y = 4.58
    BASE_HEIGHTS = {prestador: 3.40, tomador: 2.10, destinatario: 2.10,
      intermediario: 2.10, service: 2.10, municipal: 3.17, federal: 1.60,
      ibs: 3.25, totals: 1.67, complementary: 1.90, receipt: 0.80}.freeze
    COMPLEMENTARY_CONTENT_OFFSET = 0.72
    AUTHENTICITY_LEADING = 0
  end
end
