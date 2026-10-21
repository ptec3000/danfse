# danfse

Gera o PDF do DANFSe a partir do XML autorizado da NFS-e Nacional, conforme a NT 008 v1.02. Não emite notas nem consulta a situação delas no portal nacional.

## Instalação

Requer Ruby 3.2 ou superior. No Gemfile:

```ruby
gem "danfse", github: "ptec3000/danfse", tag: "v0.1.1"
```

Execute `bundle install`.

## Uso em Ruby

```ruby
require "danfse"

xml = File.read("nota.xml")
pdf = Danfse.render(xml) # String binária com o PDF
File.binwrite("nota.pdf", pdf)

Danfse.render_file("nota.xml", "nota.pdf", situacao: :cancelada, canhoto: true)
# => "nota.pdf"
```

As opções são `situacao: :normal`, `canhoto: false` e `fonts: nil`. `situacao:` aceita `:normal`, `:cancelada` e `:substituida`; outro valor gera `ArgumentError`. Qualquer entrada XML inválida gera `Danfse::InvalidXml`, que herda de `Danfse::Error`.

Em Rails, supondo um modelo `Nota` com os anexos Active Storage `xml` e `danfse`, um job pode gerar o PDF a partir do XML guardado:

```ruby
class GerarDanfseJob < ApplicationJob
  def perform(nota_id)
    nota = Nota.find(nota_id)
    pdf = Danfse.render(nota.xml.download)
    nota.danfse.attach(io: StringIO.new(pdf), filename: "danfse.pdf", content_type: "application/pdf")
  end
end
```

## Linha de comando

```sh
bundle exec danfse nota.xml > nota.pdf
bundle exec danfse nota.xml nota.pdf
bundle exec danfse --cancelada --canhoto nota.xml nota.pdf
bundle exec danfse --substituida nota.xml nota.pdf
```

Sem o segundo caminho, o PDF binário vai para stdout; com ele, o arquivo é gravado sem imprimir o PDF. `--cancelada` e `--substituida` são mutuamente exclusivas; `--canhoto` inclui o canhoto de recebimento. No checkout local, use `bundle exec ruby -Ilib exe/danfse` no lugar de `bundle exec danfse`.

O status de saída é 0 no sucesso, 1 para XML inválido, falha de geração ou erro de arquivo, e 64 para uso incorreto, inclusive ausência de argumentos. Erros vão para stderr sem backtrace; XML inválido produz `XML da NFS-e inválido: …`.

## Decisões de renderização

- **Fontes:** o PDF incorpora Liberation Sans Regular e Bold. Esta é uma divergência declarada da NT 2.4: Liberation Sans tem a mesma métrica da Arial usada nos títulos; para o conteúdo, substitui a Microsoft Sans Serif por aproximação, sem reproduzir exatamente suas métricas.
- **Situação:** quem chama informa `situacao:` a partir dos dados que mantém. A gem não deduz cancelamento ou substituição por consulta externa.
- **Canhoto:** é opcional e vem desativado por padrão.
- **Municípios:** a tabela local do IBGE permite renderizar sem acesso à rede. Para atualizá-la, execute `bundle exec ruby script/update_municipios` e revise o diff de `data/municipios.csv`.

Quem tiver as fontes originais pode fornecer os caminhos TrueType por papel: `regular:` para o conteúdo e `bold:` para os títulos, respeitando as respectivas licenças:

```ruby
Danfse.render(xml, fonts: {
  regular: "/caminho/Microsoft-Sans-Serif.ttf",
  bold: "/caminho/Arial-Bold.ttf"
})
```

Caracteres ausentes nas fontes fornecidas usam Liberation Sans como alternativa; se também estiverem ausentes nela, aparecem como `?`.

## Licenças e origem dos dados

| Item | Licença ou condição de uso | Origem |
| --- | --- | --- |
| Código da gem | MIT, conforme [LICENSE](LICENSE) | Este projeto |
| Liberation Sans Regular e Bold | SIL OFL 1.1; nome mantido e licença distribuída em [OFL.txt](assets/fonts/OFL.txt) | [Liberation Fonts 2.1.5](https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-2.1.5.tar.gz) |
| Logomarca da NFS-e | Logomarca oficial do gov.br; uso exigido pela NT 2.4.3 | [Logo horizontal da NFS-e](https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/logos-da-nfs-e/Logo%20-%20NFS-e%20-%20Horizontal.png/view) |
| Tabela de municípios | Dado público do IBGE | [API de localidades v1 do IBGE](https://servicodados.ibge.gov.br/api/v1/localidades/municipios) |

Os assets e os dados não são licenciados sob MIT pela gem. A licença MIT se aplica ao código; cada item acima conserva suas condições próprias.

As fontes e a logo foram obtidas sem alteração em 20/10/2026. O CSV foi gerado nessa data por `script/update_municipios`, com 5.571 municípios. A logo e a base do IBGE não possuem versão individual informada na origem; os hashes SHA256 identificam as cópias distribuídas:

| Arquivo | SHA256 |
| --- | --- |
| `assets/fonts/LiberationSans-Regular.ttf` | `76d04c18ea243f426b7de1f3ad208e927008f961dc5945e5aad352d0dfde8ee8` |
| `assets/fonts/LiberationSans-Bold.ttf` | `788abee4c806d660e8aee46689dd8540cd4bb98da03dcc9d171ce3efd99a9173` |
| `assets/fonts/OFL.txt` | `93fed46019c38bbe566b479d22148e2e8a1e85ada614accb0211c37b2c61c19b` |
| `assets/logo-nfse.png` | `ab57fa34887929a10ee3b9b4d666084ec9b9465e62bbcc3523b99b23ccac1063` |
| `data/municipios.csv` | `db1d0753899e0a506876711b33758056e1e38ce32cef3eab1f19fad44f3eca24` |

## Contribuição

Instale as dependências com `bundle install` e execute:

```sh
bundle exec rake test
bundle exec rake render_fixtures
```

Os testes verificam a leitura do XML e o conteúdo dos PDFs. `render_fixtures` gera em `tmp/` os PDFs de todas as fixtures e um exemplo cancelado, para inspeção visual. Ao contribuir, inclua um teste que reproduza a mudança e confira os PDFs afetados.
