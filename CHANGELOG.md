# Changelog

## 0.1.2

- Passa a exigir Ruby 3.4 ou superior (CI em 3.4 e 4.0).

## 0.1.1 — correções

- Tratamento de erros de geração na linha de comando, com saída legível e status 1.
- Carregamento da gem fora do Bundler em Ruby 4 e verificação da instalação no CI.
- Leitura binária do XML e inclusão correta dos arquivos da gem ao carregar o gemspec de outro diretório.
- Validação da chave, do número e da DPS da NFS-e, além de valores numéricos inválidos.
- Cálculo das contribuições retidas conforme o código de retenção de PIS, COFINS e CSLL.
- Correção da localidade de prestação no exterior e do desconto incondicionado no PDF.
- Ajustes no limite de texto complementar e na redução de texto longo, preservando mais conteúdo legível.

## 0.1.0 — primeira versão

- Geração do PDF do DANFSe a partir do XML autorizado da NFS-e Nacional, conforme a NT 008 v1.02.
- API Ruby e executável `danfse`, com situação informada por quem chama, canhoto opcional e fontes configuráveis.
- Fontes Liberation Sans incorporadas, logomarca oficial da NFS-e e tabela local de municípios do IBGE.
