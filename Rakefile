require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.warning = false
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

task default: :test

desc "Render every XML fixture and the cancelled real invoice into tmp/"
task :render_fixtures do
  require "fileutils"
  require_relative "lib/danfse"

  FileUtils.mkdir_p("tmp")
  Dir["test/fixtures/**/*.xml"].sort.each do |source|
    destination = File.join("tmp", "#{File.basename(source, '.xml')}.pdf")
    Danfse.render_file(source, destination)
    puts destination
  end
  source = "test/fixtures/real/acervo_homologacao_rtc.xml"
  destination = "tmp/real_cancelada.pdf"
  Danfse.render_file(source, destination, situacao: :cancelada)
  puts destination
end
