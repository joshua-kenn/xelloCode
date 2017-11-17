# Monkey patch Middleman to make asset scanning faster
module Middleman
  class FakeAsset < Sprockets::Asset
    attr_reader :logical_path

    def initialize(app, logical_path)
      @app = app
      @logical_path = logical_path
    end

    def source_dir
      @source_dir ||= app.settings.source
    end

    def destination_path
      destination_path_as_type type
    end

    def destination_path_as_type(file_type)
      prefix = case file_type
        when :image
          app.settings.images_dir
        when :script
          app.settings.js_dir
        when :stylesheet
          app.settings.css_dir
        when :font
          app.settings.fonts_dir
        else
          nil
      end
      (prefix.nil? || logical_path.to_s.start_with?(prefix)) ? logical_path.to_s : File.join(prefix,
        logical_path.to_s)
    end

    def source_path
      logical_path
    end

    def has_extname? *exts
      !(exts & logical_path.to_s.scan(/(\.[^.]+)/).flatten).empty?
    end

    def is_svg_by_extension?
      has_extname? %w(.svg)
    end
  end

  class SprocketsExtension
    def manipulate_resource_list(resources)
      resources_list = []
      to_delete = []
      source_root = File.join(@app.root, @app.settings.source)
      environment.imported_assets.each do |imported_asset|
        # Skip entries under source root using a much faster FakeAsset implementation
        fake_asset = FakeAsset.new(@app, imported_asset.logical_path)
        if imported_asset.output_path
          destination = imported_asset.output_path.to_s
        else
          destination = @app.sitemap.extensionless_path(fake_asset.destination_path.to_s)
        end
        next if File.exists? File.join(source_root, destination)

        # Svg special case; look in both images and fonts folder
        if fake_asset.is_svg_by_extension?
          next if File.exists? File.join(source_root, fake_asset.destination_path_as_type(:image))
          next if File.exists? File.join(source_root, fake_asset.destination_path_as_type(:font))
        end

        # Assets outside source root can use the slower method for creating a resource
        begin
          asset = Middleman::Sprockets::Asset.new(@app, imported_asset.logical_path, environment)
          unless imported_asset.output_path
            destination = @app.sitemap.extensionless_path(asset.destination_path.to_s)
          end
          resource = Middleman::Sitemap::Resource.new(@app.sitemap, destination,
            asset.source_path.to_s)
          resource.add_metadata options: { sprockets: { logical_path: imported_asset.logical_path }}
          resources_list << resource
        rescue ::Sprockets::FileNotFound
          to_delete << imported_asset
          @app.logger.warn "File not found: #{destination}"
        end
      end

      to_delete.each do |imported_asset|
        environment.imported_assets.delete imported_asset
      end

      resources + resources_list
    end
  end
end
