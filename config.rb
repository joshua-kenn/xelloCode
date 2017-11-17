# Middleman Optimizations
require 'middleman/optimizations'
activate :sassc

# Asset paths
set :css_dir, 'css'
set :js_dir, 'js'
set :font_dir, 'fonts'
set :images_dir, 'images'
set :partials_dir, 'partials'

# Find path of a gem
def gem_dir(name)
  specs = Gem::Specification.latest_specs true
  gem = specs.find { |spec| spec.name == name }
  gem.nil? ? nil : gem.gem_dir
end

# Make external files available to Sprockets
sprockets.append_path File.join(gem_dir('babel-source'), 'lib')
sprockets.append_path File.join(gem_dir('sprockets-babel'), 'lib')

# Import bootstrap assets
bower_path = File.join(root, 'bower_components')
bootstrap_path = File.join(bower_path, 'bootstrap-sass/assets')
bootstrap_fonts_path = File.join(bootstrap_path, 'fonts')
sprockets.append_path bootstrap_fonts_path
sprockets.append_path File.join(bootstrap_path, 'javascripts')
sprockets.append_path File.join(bootstrap_path, 'stylesheets')

# Import font-awesome assets
font_awesome_path = File.join(bower_path, 'font-awesome')
font_awesome_fonts_path = File.join(font_awesome_path, 'fonts')
sprockets.append_path font_awesome_fonts_path
sprockets.append_path File.join(font_awesome_path, 'scss')

# Import remaining bower assets
sprockets.append_path File.join(bower_path, 'js-commons/source/js')
sprockets.append_path File.join(bower_path, 'ang-notations/source/js')
sprockets.append_path File.join(bower_path, 'stomp-over-websocket-client/source/js')
sprockets.append_path File.join(bower_path, 'bourbon/app/assets/stylesheets')
sprockets.append_path bower_path

# Profile switch
@config_file = File.exists?(File.join(root, 'configs', 'local.js')) ? 'local' : 'warwick'
if ENV['CONFIG']
  @config_file = ENV['CONFIG']
end
set :config_file, @config_file

# Configure Babel
require 'babel'
::Babel.options.merge!({
  loose: %w{es6.classes es6.modules}, # loose mode enables better IE <= 10 compatibility
  stage: 1,
  modules: 'amd'
})

# Exclude included files
ignore 'css/includes/*'
ignore 'css/vendor/*'
ignore 'fonts/*.otf'
ignore 'js/app/*'
ignore 'js/controllers/*'
ignore 'js/data/*'
ignore 'js/directives/*'
ignore 'js/filters/*'
ignore 'js/services/*'
ignore 'js/utils/*'
ignore 'js/config.js'
ignore 'js/constants.js'

# Page helpers
helpers do
  def current_page_path
    path = request.nil? ? Thread.current[:current_path] : request.path
    return '' if path.nil?

    # remove index.html
    tokens = path.split('/')
    if tokens[-1] == 'index.html'
      tokens.pop
    end

    # drop html extension
    unless tokens.empty?
      tokens[-1] = tokens[-1].sub(/\.html$/, '')
    end

    tokens.join('/')
  end
end

config[:file_watcher_ignore] += [
  %r{\.idea\/},
  %r{\.iml}
]

# Dev-specific configuration
configure :development do
  set :debug_assets, true

  # reload page
  activate :livereload
end

# Build-specific configuration
configure :build do
  set :http_prefix, '/'

  # Output .js.es6 files as .js
  def remap_es6_files(dir)
    Dir.foreach(File.join(config[:source], dir)) do |file|
      next if file == '.' or file == '..'

      path = File.join(dir, file)
      if File.directory?(File.join(config[:source], path))
        remap_es6_files(path)
      elsif file =~ /\.es6$/
        proxy path.gsub(/\.es6$/, ''), path
        ignore path
      elsif file =~ /\.es6\.erb$/
        proxy path.gsub(/\.es6\.erb$/, ''), path.gsub(/\.erb$/, '')
        ignore path
      end
    end
  end

  remap_es6_files(config[:js_dir])

  # Minify text files
  activate :minify_html, simple_boolean_attributes: false, remove_quotes: false,
    remove_input_attributes: false
  activate :minify_css
  activate :minify_javascript, ignore: [%r{^js\/vendor\/}]
  set :js_compressor, Uglifier.new({
    output: {
      ascii_only: true,
      quote_keys: true
    },
    mangle: false,
    compress: {
      keep_fnames: true
    }
  })
end
