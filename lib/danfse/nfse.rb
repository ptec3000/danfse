# frozen_string_literal: true

require "nokogiri"
require "bigdecimal"
require "date"

module Danfse
  class Nfse
    Pessoa = Struct.new(:documento, :inscricao_municipal, :telefone, :nome,
      :municipio, :codigo_ibge_cep, :endereco, :email, keyword_init: true)

    DPS = "DPS/infDPS"
    MUNICIPAL = "#{DPS}/valores/trib/tribMun"
    FEDERAL = "#{DPS}/valores/trib/tribFed"
    PIS_COFINS = "#{FEDERAL}/piscofins"
    DISCOUNTS = "#{DPS}/valores/vDescCondIncond"
    IBS_VALUES = "IBSCBS/valores"
    IBS_TOTALS = "IBSCBS/totCIBS"
    APPROXIMATE_TAXES = "#{DPS}/valores/trib/totTrib"

    # Paths are relative to infNFSe, including the embedded DPS.
    MONEY_FIELDS = {
      desconto_incondicionado: "#{DISCOUNTS}/vDescIncond",
      bc_issqn: "valores/vBC",
      issqn_apurado: "valores/vISSQN",
      irrf: "#{FEDERAL}/vRetIRRF",
      cp_retida: "#{FEDERAL}/vRetCP",
      bc_ibscbs: "#{IBS_VALUES}/vBC",
      valor_ibs_mun: "#{IBS_TOTALS}/gIBS/gIBSMunTot/vIBSMun",
      valor_ibs_uf: "#{IBS_TOTALS}/gIBS/gIBSUFTot/vIBSUF",
      valor_ibs_total: "#{IBS_TOTALS}/gIBS/vIBSTot",
      valor_cbs: "#{IBS_TOTALS}/gCBS/vCBS",
      valor_servico: "#{DPS}/valores/vServPrest/vServ",
      desconto_incondicionado_total: "#{DISCOUNTS}/vDescIncond",
      desconto_condicionado: "#{DISCOUNTS}/vDescCond",
      total_retencoes: "valores/vTotalRet",
      valor_liquido: "valores/vLiq",
      valor_liquido_ibscbs: "#{IBS_TOTALS}/vTotNF",
    }.freeze
    MONEY_FIELDS.each do |name, path|
      define_method(name) do
        Formatters.moeda(text(path))
      rescue InvalidXml => error
        raise InvalidXml, "Valor inválido em #{path.split('/').last}: #{error.message}"
      end
    end

    PERCENT_FIELDS = {
      aliquota_aplicada: "valores/pAliqAplic",
      aliq_efetiva_mun: "#{IBS_VALUES}/mun/pAliqEfetMun",
      aliq_efetiva_uf: "#{IBS_VALUES}/uf/pAliqEfetUF",
      aliquota_cbs: "#{IBS_VALUES}/fed/pCBS",
      aliq_efetiva_cbs: "#{IBS_VALUES}/fed/pAliqEfetCBS",
    }.freeze
    PERCENT_FIELDS.each do |name, path|
      define_method(name) { Formatters.percentual(text(path)) }
    end

    def initialize(xml)
      doc = Nokogiri::XML(xml) { |config| config.strict.nonet }
      doc.remove_namespaces!
      @info = doc.at_xpath("/NFSe/infNFSe")
      raise InvalidXml, "XML sem infNFSe ou Id." unless @info && text("@Id")
      raise InvalidXml, "Id inválido; esperado NFS e 50 dígitos." unless /\ANFS\d{50}\z/.match?(text("@Id"))
      raise InvalidXml, "XML sem nNFSe ou DPS/infDPS." unless text("nNFSe") && @info.at_xpath(DPS)

      @version = doc.root["versao"]
    rescue Nokogiri::XML::SyntaxError => error
      raise InvalidXml, error.message
    end

    def chave = text("@Id").delete_prefix("NFS")
    def numero = display(text("nNFSe"))
    def competencia = Formatters.data(text("#{DPS}/dCompet"))
    def emissao_nfse = Formatters.data_hora(text("dhProc"))
    def numero_dps = display(text("#{DPS}/nDPS"))
    def serie_dps = display(text("#{DPS}/serie"))
    def emissao_dps = Formatters.data_hora(text("#{DPS}/dhEmi"))
    def emitente = description(:tp_emit, text("#{DPS}/tpEmit"))
    def situacao_nfse = description(:c_stat, text("cStat"), 37)

    def finalidade
      description(:fin_nfse, text("#{DPS}/finNFSe") || text("#{DPS}/IBSCBS/finNFSe"), 37)
    end

    def municipio_cabecalho
      return nil if text("#{DPS}/serv/cServ/cTribNac")&.start_with?("99")

      "Município: #{join_fields(text('xLocEmi'), text('emit/enderNac/UF'))}"
    end

    def ambiente_gerador = "Ambiente Gerador: #{description(:amb_ger, text('ambGer'))}"
    def tipo_ambiente = "Tipo de Ambiente: #{description(:tp_amb, text("#{DPS}/tpAmb"))}"
    def homologacao? = text("#{DPS}/tpAmb") == "2"
    def qr_url = "https://www.nfse.gov.br/ConsultaPublica/?tpc=1&chave=#{chave}"
    def canhoto_numero_chave = "#{numero} / #{chave}"

    def prestador
      provider = @info.at_xpath("#{DPS}/prest")
      return nil unless provider

      issuer = @info.at_xpath("emit")
      same_document = %w[CNPJ CPF].any? do |kind|
        document = text(kind, provider)
        document && document == text(kind, issuer)
      end
      person(provider, same_document ? issuer : nil)
    end

    def tomador = person(@info.at_xpath("#{DPS}/toma"))
    def destinatario = person(@info.at_xpath("#{DPS}/IBSCBS/dest"))
    def intermediario = person(@info.at_xpath("#{DPS}/interm"))

    def destinatario_proprio_tomador?
      text("#{DPS}/IBSCBS/indDest") == "0" && destinatario.nil? && !tomador.nil?
    end

    def prestador_simples = description(:op_simp_nac, text("#{DPS}/prest/regTrib/opSimpNac"), 37)
    def prestador_regime_sn = description(:reg_ap_trib_sn, text("#{DPS}/prest/regTrib/regApTribSN"), 77)

    def codigo_tributacao
      Formatters.codigo_tributacao(text("#{DPS}/serv/cServ/cTribNac"), text("#{DPS}/serv/cServ/cTribMun"))
    end

    def nbs = Formatters.nbs(text("#{DPS}/serv/cServ/cNBS"))

    def local_prestacao
      country = text("#{DPS}/serv/locPrest/cPaisPrestacao")
      return join_fields(text("xLocPrestacao"), "-", country) if country

      location(text("xLocPrestacao"), text("#{DPS}/serv/locPrest/cLocPrestacao"))
    end

    def descricao_tributacao = Formatters.truncar(text("xTribMun") || text("xTribNac"), 167)
    def descricao_servico = Formatters.truncar(text("#{DPS}/serv/cServ/xDescServ"), 1297)

    def issqn_incide?
      !Tables.nao_incidencia_issqn?(text("#{MUNICIPAL}/tribISSQN"), versao: @version)
    end

    def tributacao_issqn = description(:trib_issqn, text("#{MUNICIPAL}/tribISSQN"))

    def local_incidencia_issqn
      location(text("xLocIncid"), text("cLocIncid"), text("#{MUNICIPAL}/cPaisResult"))
    end

    def regime_especial = description(:reg_esp_trib, text("#{DPS}/prest/regTrib/regEspTrib"))
    def tipo_imunidade = description(:tp_imunidade, text("#{MUNICIPAL}/tpImunidade"), 37)
    def suspensao = description(:tp_susp, text("#{MUNICIPAL}/exigSusp/tpSusp"), 37)
    def processo_suspensao = display(text("#{MUNICIPAL}/exigSusp/nProcesso"))

    def beneficio_municipal
      description(:tp_bm, text("valores/tpBM") || text("#{MUNICIPAL}/BM/tpBM"))
    end

    def calculo_bm
      Formatters.moeda(text("valores/vCalcBM") || text("#{MUNICIPAL}/BM/vRedBCBM"))
    end

    def deducoes
      explicit = text("#{DPS}/valores/vDedRed/vDR")
      Formatters.moeda(explicit || sum(text("valores/vCalcDR"), text("#{IBS_VALUES}/vCalcReeRepRes")))
    end

    def retencao_issqn = description(:tp_ret_issqn, text("#{MUNICIPAL}/tpRetISSQN"))

    def linha_regime_vazia?
      ["#{DPS}/prest/regTrib/regEspTrib", "#{MUNICIPAL}/tpImunidade",
       "#{MUNICIPAL}/exigSusp/tpSusp", "#{MUNICIPAL}/exigSusp/nProcesso"].all? { |path| text(path).nil? }
    end

    def linha_beneficio_vazia?
      ["valores/tpBM", "#{MUNICIPAL}/BM/tpBM", "valores/vCalcBM", "#{MUNICIPAL}/BM/vRedBCBM",
       "#{DPS}/valores/vDedRed/vDR", "valores/vCalcDR", "#{IBS_VALUES}/vCalcReeRepRes",
       "#{DISCOUNTS}/vDescIncond"].all? { |path| text(path).nil? }
    end

    def contribuicoes_retidas
      taxes = retained_taxes
      amount = sum(*{
        csll: text("#{FEDERAL}/vRetCSLL"),
        pis: text("#{PIS_COFINS}/vPis"),
        cofins: text("#{PIS_COFINS}/vCofins")
      }.filter_map { |tax, value| value if taxes.include?(tax) })
      Formatters.moeda(amount)
    end

    def pis_proprio = Formatters.moeda(retained_taxes.include?(:pis) ? "0" : text("#{PIS_COFINS}/vPis"))
    def cofins_proprio = Formatters.moeda(retained_taxes.include?(:cofins) ? "0" : text("#{PIS_COFINS}/vCofins"))
    def descricao_contribuicoes_retidas = description(:tp_ret_pis_cofins, text("#{PIS_COFINS}/tpRetPisCofins"))

    def mostrar_pis_cofins_proprio?
      date = text("#{DPS}/dCompet")
      !date.nil? && Date.iso8601(date) <= Date.new(2026, 12, 31)
    rescue ArgumentError => error
      raise InvalidXml, "Competência inválida: #{error.message}"
    end

    def cst_cclasstrib
      prefix = "#{DPS}/IBSCBS/valores/trib"
      join_fields(text("#{prefix}/gIBSCBS/CST") || text("#{prefix}/CST"),
        text("#{prefix}/gIBSCBS/cClassTrib") || text("#{prefix}/cClassTrib"))
    end

    def indicador_operacao
      code = text("IBSCBS/cLocalidadeIncid")
      join_fields(text("#{DPS}/IBSCBS/cIndOp"), code, text("IBSCBS/xLocalidadeIncid"), Municipios.uf(code))
    end

    def exclusoes_reducoes
      Formatters.moeda(sum(text("#{DISCOUNTS}/vDescIncond"), text("#{IBS_VALUES}/vCalcReeRepRes"),
        text("valores/vISSQN"), text("#{PIS_COFINS}/vPis"), text("#{PIS_COFINS}/vCofins")))
    end

    def red_aliquotas
      percentage_fields("#{IBS_VALUES}/uf/pRedAliqUF", "#{IBS_VALUES}/mun/pRedAliqMun", "#{IBS_VALUES}/fed/pRedAliqCBS")
    end

    def aliquotas_ibs
      percentage_fields("#{IBS_VALUES}/uf/pIBSUF", "#{IBS_VALUES}/mun/pIBSMun")
    end

    def total_ibscbs
      Formatters.moeda(sum(text("#{IBS_TOTALS}/gIBS/vIBSTot"), text("#{IBS_TOTALS}/gCBS/vCBS")))
    end

    def informacoes_complementares
      paths = [
        ["Inf. Cont.", "#{DPS}/serv/infoCompl/xInfComp"],
        ["NFS-e Subst.", "#{DPS}/subst/chSubstda"],
        ["Doc. Ref.", "#{DPS}/serv/infoCompl/docRef"],
        ["Cod. Obra", "#{DPS}/serv/obra/cObra"],
        ["Insc. Imob.", "#{DPS}/IBSCBS/imovel/inscImobFisc", "#{DPS}/serv/obra/inscImobFisc"],
        ["Cod. Evt.", "#{DPS}/serv/atvEvento/idAtvEvt", "#{DPS}/serv/atvEvento/id"],
        ["Doc. Tec.", "#{DPS}/serv/infoCompl/idDocTec"],
        ["Núm. Ped.", "#{DPS}/serv/infoCompl/xPed"],
        ["Item Ped.", "#{DPS}/serv/infoCompl/gItemPed/xItemPed"],
      ]
      items = paths.flat_map do |label, path, alternative|
        path = alternative if alternative && !text(path)
        @info.xpath(path).filter_map do |node|
          value = text(".", node)
          "#{label}: #{value}" if value
        end
      end
      other = text("xOutInf") || text("valores/xOutInf")
      items << "Inf. A. T. Mun.: #{other}" if other
      simples = text("#{APPROXIMATE_TAXES}/pTotTribSN")
      suffix = "Total Simples Nacional: #{Formatters.percentual(simples)}" if simples
      limit_complementary_items(items, suffix)
    end

    def totais_tributos
      values = %w[Fed Est Mun].map do |suffix|
        if text("#{APPROXIMATE_TAXES}/indTotTrib") == "0"
          "-"
        else
          amount = text("#{APPROXIMATE_TAXES}/vTotTrib/vTotTrib#{suffix}")
          amount ? Formatters.moeda(amount) : Formatters.percentual(text("#{APPROXIMATE_TAXES}/pTotTrib/pTotTrib#{suffix}"))
        end
      end
      "Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Federais: #{values[0]}; Estaduais: #{values[1]}; Municipais: #{values[2]}"
    end

    private

    def text(path, node = @info)
      value = node&.at_xpath(path)&.text&.strip
      value unless value.nil? || value.empty?
    end

    def display(value) = value || "-"

    def description(field, code, threshold = nil)
      value = Tables.descricao(field, code, versao: @version)
      threshold ? Formatters.truncar(value, threshold) : display(value)
    end

    def join_fields(*values)
      return "-" if values.all? { |value| value.nil? || value == "-" }

      values.map { |value| display(value) }.join(" / ")
    end

    def location(name, code, country = nil)
      return "-" if [name, code, country].all?(&:nil?)

      join_fields(name, Municipios.uf(code), country || "BR")
    end

    def percentage_fields(*paths)
      values = paths.map { |path| text(path) }
      return "-" if values.all?(&:nil?)

      values.map { |value| Formatters.percentual(value) }.join(" / ")
    end

    def sum(*values)
      present = values.compact
      return nil if present.empty?

      present.sum(BigDecimal("0")) do |value|
        begin
          decimal = BigDecimal(value.to_s)
          raise InvalidXml, "Valor numérico inválido: #{value}" unless decimal.finite?

          decimal
        rescue ArgumentError
          raise InvalidXml, "Valor numérico inválido: #{value}"
        end
      end
    end

    # Count separators in the NT character budget and reserve the SN total.
    # The mandatory approximate-tax line is separate and is never truncated.
    def limit_complementary_items(items, suffix)
      complete = suffix ? items + [suffix] : items
      return complete if complete.join(" | ").length <= 1997

      remaining = 1997 - (suffix ? suffix.length + 3 : 0)
      result = []
      items.each do |item|
        separator = result.empty? ? 0 : 3
        if item.length + separator <= remaining
          result << item
          remaining -= item.length + separator
        else
          if remaining > separator
            result << Formatters.truncar(item, remaining - separator)
          else
            result[-1] += "..."
          end
          break
        end
      end
      result << suffix if suffix
      result
    end

    # v1.01 enumerates each retained tax; v1.00 codes 1/2 keep their meaning.
    def retained_taxes
      code = text("#{PIS_COFINS}/tpRetPisCofins")
      return code == "1" ? %i[pis cofins csll] : %i[csll] if @version == "1.00"

      {
        "0" => [], "1" => %i[pis cofins csll], "2" => %i[csll],
        "3" => %i[pis cofins csll], "4" => %i[pis cofins],
        "5" => %i[pis], "6" => %i[cofins], "7" => %i[cofins csll],
        "8" => %i[csll], "9" => %i[pis csll]
      }.fetch(code, %i[csll])
    end

    def person(node, fallback = nil)
      return nil unless node

      field = ->(path) { text(path, node) || text(path, fallback) }
      document = Formatters.documento(cnpj: text("CNPJ", node), cpf: text("CPF", node), nif: text("NIF", node))
      document = description(:c_nao_nif, text("cNaoNIF", node)) if document == "-"
      address_node = node.at_xpath("end") || fallback&.at_xpath("enderNac")
      foreign = address_node&.at_xpath("endExt")
      address_field = ->(tag) { text(tag, address_node) }
      if foreign
        municipality = join_fields(text("xCidade", foreign), text("xEstProvReg", foreign))
        postal = "- / #{display(text('cEndPost', foreign))}"
      else
        national = node.at_xpath("end") ? address_node&.at_xpath("endNac") : address_node
        code = text("cMun", national)
        postal_code = text("CEP", national)
        municipality = display(Municipios.nome_uf(code))
        postal = join_fields(code, postal_code && Formatters.cep(postal_code))
      end
      address = %w[xLgr nro xCpl xBairro].filter_map { |tag| address_field.call(tag) }.join(", ")
      Pessoa.new(documento: document, inscricao_municipal: display(field.call("IM")),
        telefone: display(field.call("fone")), nome: Formatters.truncar(field.call("xNome"), 77),
        municipio: municipality, codigo_ibge_cep: postal, endereco: Formatters.truncar(address, 77),
        email: display(field.call("email")))
    end
  end
end
