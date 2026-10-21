# frozen_string_literal: true

require "prawn"
require "rqrcode"

module Danfse
  class Document
    attr_reader :qr_modules

    def initialize(nfse, situacao: :normal, canhoto: false, fonts: nil)
      unless %i[normal cancelada substituida].include?(situacao)
        raise ArgumentError, "Situação inválida: #{situacao}"
      end

      @nfse = nfse
      @situation = situacao
      @receipt = canhoto
      if fonts && !(fonts.is_a?(Hash) && fonts.key?(:regular) && fonts.key?(:bold))
        raise ArgumentError, "fonts: precisa das chaves :regular e :bold"
      end
      @fonts = fonts
      @qr_modules = RQRCode::QRCode.new(nfse.qr_url, level: :m).modules
    end

    def render
      prepare_layout
      draw_watermark
      draw_frame
      draw_header
      draw_identification
      @y = Layout::START_Y
      Layout::PERSON_TITLES.each_key { |role| draw_person(role) }
      draw_service
      draw_municipal
      draw_federal
      draw_fields_block(Layout::IBS, :ibs)
      draw_fields_block(Layout::TOTALS, :totals)
      draw_complementary
      draw_receipt if @receipt
      @pdf.render
    end

    def heights
      prepare_layout unless @heights
      @heights.dup.freeze
    end

    private

    def prepare_layout
      @pdf = Prawn::Document.new(page_size: "A4", margin: 0)
      register_fonts
      calculate_heights
    end

    def cm(value) = Layout.cm(value)
    def top(value) = @pdf.bounds.top - cm(value)

    def register_fonts
      bundled = {normal: FONT_DIR.join("LiberationSans-Regular.ttf").to_s,
        bold: FONT_DIR.join("LiberationSans-Bold.ttf").to_s}
      selected = @fonts ? {normal: @fonts.fetch(:regular).to_s, bold: @fonts.fetch(:bold).to_s} : bundled
      @pdf.font_families.update("Liberation" => selected, "BundledLiberation" => bundled)
      @pdf.font("Liberation", size: Layout::FONT_SIZE)
      @pdf.fallback_fonts = ["BundledLiberation"]
      @faces = %i[normal bold].to_h do |style|
        [style, %w[Liberation BundledLiberation].map { |family| @pdf.font(family, style: style) }]
      end
      @pdf.font("Liberation", style: :normal, size: Layout::FONT_SIZE)
      @glyphs = {}
    end

    # A custom role font falls back to the bundled face. If neither face has the
    # character, use a visible question mark rather than silently losing data.
    def safe(value, style = :normal)
      value.to_s.tr("\t", " ").each_char.map do |character|
        next character if ["\n", "\r"].include?(character)

        key = [style, character]
        @glyphs[key] ||= begin
          present = @faces.fetch(style).any? { |face| face.glyph_present?(character) }
          present ? character : "?"
        end
      end.join
    end

    def text_options(field, size: Layout::FONT_SIZE, style: :normal, inset: Layout::INSET, vertical_inset: Layout::VERTICAL_INSET, **options)
      {at: [cm(field[:x] + inset), top(field[:y] + vertical_inset)],
       width: cm(field[:w] - 2 * inset), height: cm(field[:h] - 2 * vertical_inset),
       size: size, style: style, overflow: :truncate,
       fallback_fonts: ["BundledLiberation"]}.merge(options)
    end

    def box(text, field, **options)
      @pdf.text_box(safe(text, options.fetch(:style, :normal)), text_options(field, **options))
    end

    def single_line_box(text, field, size: Layout::FONT_SIZE, min_font_size: Layout::CONTENT_MIN_SIZE, **options)
      source = safe(text).gsub(/\s+/, " ").strip
      text_options = text_options(field, size: size, single_line: true,
        overflow: :shrink_to_fit, min_font_size: min_font_size, **options)
      remainder = Prawn::Text::Box.new(source, text_options.merge(document: @pdf)).render(dry_run: true)
      source = ellipsized_text(source, text_options.merge(size: min_font_size, overflow: :truncate)) unless remainder.empty?
      @pdf.text_box(source, text_options)
    end

    def ellipsized_text(source, options)
      low = 0
      high = source.length
      best = nil
      while low <= high
        middle = (low + high) / 2
        candidate = "#{source[0, middle].rstrip}..."
        remainder = Prawn::Text::Box.new(candidate, options.merge(document: @pdf)).render(dry_run: true)
        if remainder.empty?
          best = candidate
          low = middle + 1
        else
          high = middle - 1
        end
      end
      best || raise(Error, "Fonte grande demais para o quadro de texto.")
    end

    def measured_height(text, width)
      @pdf.height_of(safe(text), width: cm(width - 2 * Layout::INSET),
        size: Layout::FONT_SIZE, fallback_fonts: ["BundledLiberation"]) / cm(1) + 2 * Layout::VERTICAL_INSET
    end

    def calculate_heights
      @heights = Layout::BASE_HEIGHTS.dup
      %i[tomador destinatario intermediario].each do |role|
        @heights[role] = Layout::COLLAPSED unless @nfse.public_send(role)
      end
      if @nfse.issqn_incide?
        @heights[:municipal] -= Layout::REGIME_HEIGHT if @nfse.linha_regime_vazia?
        @heights[:municipal] -= Layout::BENEFIT_HEIGHT if @nfse.linha_beneficio_vazia?
      else
        @heights[:municipal] = Layout::COLLAPSED
      end
      @heights[:federal] -= Layout::FEDERAL_OPTIONAL_HEIGHT unless @nfse.mostrar_pis_cofins_proprio?
      @heights[:receipt] = 0 unless @receipt

      @complementary_text = @nfse.informacoes_complementares.join(" | ")
      @tax_height = measured_height(@nfse.totais_tributos, Layout::WIDTH)
      complementary_min = Layout::COMPLEMENTARY_CONTENT_OFFSET + Layout::TAX_GAP + @tax_height
      complementary_min += measured_height(@complementary_text, Layout::WIDTH) unless @complementary_text.empty?
      released = Layout::BASE_HEIGHTS.values.sum - @heights.values.sum
      available = Layout::BASE_HEIGHTS[:complementary] + released
      # Only the base complementary block is guaranteed. Released height goes
      # first to the service description; any remainder returns to this block.
      complementary_min = [complementary_min, Layout::BASE_HEIGHTS[:complementary]].min
      spare = available - complementary_min
      base_description = Layout::SERVICE[:descricao_servico][:h]
      needed = Layout::LABEL_HEIGHT + measured_height(@nfse.descricao_servico, Layout::WIDTH)
      extra = [[needed - base_description, 0].max, spare].min
      @heights[:service] += extra
      @heights[:complementary] = complementary_min + spare - extra
    end

    def shade(field)
      @pdf.fill_color(Layout::SHADE_COLOR)
      @pdf.fill_rectangle([cm(field[:x]), top(field[:y])], cm(field[:w]), cm(field[:h]))
      @pdf.fill_color("000000")
    end

    def divider(y)
      @pdf.line_width = Layout::DIVIDER_WIDTH
      @pdf.stroke_horizontal_line(cm(Layout::LEFT), cm(Layout::LEFT + Layout::WIDTH), at: top(y))
    end

    def draw_frame
      @pdf.line_width = Layout::FRAME_WIDTH
      @pdf.stroke_rectangle([cm(Layout::BORDER), top(Layout::BORDER)],
        @pdf.bounds.width - 2 * cm(Layout::BORDER), @pdf.bounds.height - 2 * cm(Layout::BORDER))
    end

    def draw_watermark
      return if @situation == :normal

      label = @situation == :cancelada ? "CANCELADA" : "SUBSTITUÍDA"
      center = Layout::WATERMARK_CENTER
      @pdf.fill_color("A6A6A6")
      @pdf.rotate(Layout::WATERMARK_ANGLE, origin: [cm(center[0]), top(center[1])]) do
        box(label, Layout::WATERMARK_BOX, size: Layout::WATERMARK_SIZE, align: :center, valign: :center)
      end
      @pdf.fill_color("000000")
    end

    def draw_header
      fields = Layout::HEADER
      shade(fields[:background])
      logo = fields[:logo]
      @pdf.image(LOGO_PATH.to_s, at: [cm(logo[:x]), top(logo[:y])], fit: [cm(logo[:w]), cm(logo[:h])])
      box(fields[:title][:label], fields[:title], size: Layout::HEADER_SIZE, style: :bold, align: :center, vertical_inset: 0)
      if @nfse.homologacao?
        @pdf.fill_color("FF0000")
        box(fields[:warning][:label], fields[:warning], size: Layout::HEADER_SIZE, style: :bold, align: :center)
        @pdf.fill_color("000000")
      end
      single_line_box(@nfse.municipio_cabecalho, fields[:municipio_cabecalho],
        size: Layout::MUNICIPALITY_SIZE, min_font_size: Layout::HEADER_MIN_SIZE) if @nfse.municipio_cabecalho
      single_line_box(@nfse.ambiente_gerador, fields[:ambiente_gerador],
        size: Layout::ENVIRONMENT_SIZE, min_font_size: Layout::HEADER_MIN_SIZE, vertical_inset: 0)
      single_line_box(@nfse.tipo_ambiente, fields[:tipo_ambiente],
        size: Layout::ENVIRONMENT_SIZE, min_font_size: Layout::HEADER_MIN_SIZE, vertical_inset: 0)
      divider(Layout::IDENTIFICATION[:chave][:y])
    end

    def draw_identification
      Layout::IDENTIFICATION.each do |name, field|
        shade(field) if name == :emitente
        draw_field(field, @nfse.public_send(name), identification: true)
      end
      qr = Layout::HEADER[:qr]
      unit = cm(qr[:w]) / @qr_modules.size
      @qr_modules.each_with_index do |row, row_index|
        row.each_with_index do |dark, column_index|
          next unless dark

          @pdf.fill_rectangle([cm(qr[:x]) + column_index * unit, top(qr[:y]) - row_index * unit], unit, unit)
        end
      end
      box(Layout::AUTHENTICITY, Layout::HEADER[:authenticity],
        size: Layout::AUTHENTICITY_SIZE, leading: Layout::AUTHENTICITY_LEADING)
    end

    def fitted_label_size(field, preferred, minimum)
      width = @pdf.width_of(safe(field[:label], :bold), size: preferred, style: :bold)
      available = cm(field[:w] - 2 * Layout::INSET) * Layout::LABEL_FIT_RATIO
      [[preferred * available / width, preferred].min, minimum].max
    end

    def draw_field(field, value, identification: false, title: false, single_line: true)
      if title
        title_field = field.merge(h: Layout::TITLE_HEIGHT)
        shade(title_field)
        size = fitted_label_size(field, Layout::TITLE_SIZE, Layout::TITLE_MIN_SIZE)
        box(field[:label], title_field.merge(h: Layout::TITLE_TEXT_HEIGHT), size: size, style: :bold)
        return
      end
      if field[:label]
        size = identification ? Layout::IDENTIFICATION_SIZE : fitted_label_size(field, Layout::LABEL_SIZE, Layout::LABEL_MIN_SIZE)
        label_height = @pdf.height_of(safe(field[:label], :bold),
          width: cm(field[:w] - 2 * Layout::INSET), size: size, style: :bold) / cm(1)
        offset = label_height + Layout::VALUE_GAP
        box(field[:label], field.merge(h: offset + 2 * Layout::VERTICAL_INSET), size: size, style: :bold)
        field = field.merge(y: field[:y] + offset, h: field[:h] - offset)
      end
      if single_line
        single_line_box(value, field)
      else
        box(value, field)
      end
    end

    def draw_person(role)
      divider(@y)
      person = @nfse.public_send(role)
      if !person && role != :prestador
        label = role == :destinatario && @nfse.destinatario_proprio_tomador? ? Layout::SAME_RECIPIENT : Layout::PERSON_MISSING.fetch(role)
        collapsed(label)
      else
        offset = @y - Layout::PERSON_ORIGINS.fetch(role)
        Layout::PEOPLE.fetch(role).each do |name, field|
          value = if name.to_s.start_with?("prestador_")
            @nfse.public_send(name)
          elsif name != :title
            person ? person.public_send(name) : "-"
          end
          draw_field(field.merge(y: field[:y] + offset), value, title: name == :title)
        end
      end
      @y += @heights.fetch(role)
    end

    def collapsed(label)
      field = {label: label, x: Layout::LEFT, y: @y, w: Layout::WIDTH, h: Layout::COLLAPSED}
      box(label, field, size: Layout::COLLAPSED_SIZE, align: :center, valign: :center, vertical_inset: 0)
    end

    def long_box(text, field)
      source = safe(text)
      options = text_options(field)
      remainder = Prawn::Text::Box.new(source, options.merge(document: @pdf)).render(dry_run: true)
      source = ellipsized_text(source, options) unless remainder.empty?
      @pdf.text_box(source, options)
    end

    def draw_service
      divider(@y)
      offset = @y - Layout::SERVICE[:title][:y]
      Layout::SERVICE.each do |name, field|
        field = field.merge(y: field[:y] + offset)
        if name == :descricao_servico
          field = field.merge(h: field[:h] + @heights[:service] - Layout::BASE_HEIGHTS[:service])
          box(field[:label], field.merge(h: Layout::LABEL_HEIGHT), size: Layout::SERVICE_LABEL_SIZE, style: :bold)
          long_box(@nfse.descricao_servico, field.merge(y: field[:y] + Layout::LABEL_HEIGHT, h: field[:h] - Layout::LABEL_HEIGHT))
        else
          if name == :descricao_tributacao
            long_box(@nfse.descricao_tributacao, field)
          else
            draw_field(field, name == :title ? nil : @nfse.public_send(name), title: name == :title)
          end
        end
      end
      @y += @heights[:service]
    end

    def draw_municipal
      divider(@y)
      unless @nfse.issqn_incide?
        collapsed(Layout::NO_ISSQN)
        @y += @heights[:municipal]
        return
      end
      offset = @y - Layout::MUNICIPAL[:title][:y]
      Layout::MUNICIPAL.each do |name, field|
        next if @nfse.linha_regime_vazia? && Layout::REGIME_FIELDS.include?(name)
        next if @nfse.linha_beneficio_vazia? && Layout::BENEFIT_FIELDS.include?(name)

        shift = 0
        shift += Layout::REGIME_HEIGHT if @nfse.linha_regime_vazia? && field[:y] > Layout::MUNICIPAL[:regime_especial][:y]
        shift += Layout::BENEFIT_HEIGHT if @nfse.linha_beneficio_vazia? && field[:y] > Layout::MUNICIPAL[:beneficio_municipal][:y]
        draw_field(field.merge(y: field[:y] + offset - shift), name == :title ? nil : @nfse.public_send(name), title: name == :title)
      end
      @y += @heights[:municipal]
    end

    def draw_federal
      fields = Layout::FEDERAL
      fields = fields.slice(:title, :irrf, :cp_retida, :contribuicoes_retidas) unless @nfse.mostrar_pis_cofins_proprio?
      draw_fields_block(fields, :federal)
    end

    def draw_fields_block(fields, name)
      divider(@y)
      offset = @y - fields[:title][:y]
      fields.each do |key, field|
        moved = field.merge(y: field[:y] + offset)
        shade(moved) if key == :valor_liquido_ibscbs
        draw_field(moved, key == :title ? nil : @nfse.public_send(key), title: key == :title)
      end
      @y += @heights.fetch(name)
    end

    def draw_complementary
      divider(@y)
      offset = @y - Layout::COMPLEMENTARY[:title][:y]
      title = Layout::COMPLEMENTARY[:title].merge(y: @y)
      draw_field(title, nil, title: true)
      field = Layout::COMPLEMENTARY[:content].merge(y: Layout::COMPLEMENTARY[:content][:y] + offset,
        h: @heights[:complementary] - Layout::COMPLEMENTARY_CONTENT_OFFSET - Layout::TAX_GAP - @tax_height)
      long_box(@complementary_text, field) unless @complementary_text.empty?
      # Keep the mandatory totals immediately after the measured complementary
      # text, or at the reserved bottom if the text fills its allotted space.
      used = @complementary_text.empty? ? 0 : [measured_height(@complementary_text, field[:w]), field[:h]].min
      box(@nfse.totais_tributos, field.merge(y: field[:y] + used + Layout::TAX_GAP, h: @tax_height))
      @y += @heights[:complementary]
    end

    def draw_receipt
      Layout::RECEIPT.each do |name, field|
        moved = field.merge(y: field[:y] + @y - Layout::RECEIPT[:date][:y])
        @pdf.line_width = Layout::DIVIDER_WIDTH
        @pdf.stroke_rectangle([cm(moved[:x]), top(moved[:y])], cm(moved[:w]), cm(moved[:h]))
        draw_field(moved, name == :canhoto_numero_chave ? @nfse.canhoto_numero_chave : "")
      end
    end
  end
end
