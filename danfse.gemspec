require_relative "lib/danfse/version"

Gem::Specification.new do |spec|
  spec.name = "danfse"
  spec.version = Danfse::VERSION
  spec.authors = ["Acervo Tecnologia"]
  spec.summary = "Gera o PDF do DANFSe (NFS-e Nacional, NT 008/2026) a partir do XML autorizado"
  spec.description = "Converte o XML autorizado da NFS-e Nacional em PDF do DANFSe conforme a NT 008 v1.02. " \
    "Funciona em Ruby, sem Rails e sem binários externos."
  spec.email = ["pedro@acervotecnologia.com.br"]
  spec.homepage = "https://github.com/ptec3000/danfse"
  spec.metadata = {
    "source_code_uri" => "https://github.com/ptec3000/danfse",
    "changelog_uri" => "https://github.com/ptec3000/danfse/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/ptec3000/danfse/issues",
    "rubygems_mfa_required" => "true"
  }
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "assets/**/*", "data/**/*", "exe/*", "LICENSE", "README.md", "CHANGELOG.md"]
      .select { |path| File.file?(path) }
  end
  spec.bindir = "exe"
  spec.executables = ["danfse"]

  spec.add_dependency "prawn", "~> 2.5"
  spec.add_dependency "rqrcode", "~> 3.0"
  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "csv"
  spec.add_dependency "bigdecimal"
end
