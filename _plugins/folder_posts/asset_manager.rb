#!/usr/bin/env ruby
#
# Asset manager for folder-based posts
# This module handles copying and managing post assets (images, etc.)

require_relative 'utils'

module Jekyll
  module FolderPosts
    module AssetManager
      # Copy all post assets from pic folders to site destination
      def self.copy_post_assets(site)
        asset_files = Dir.glob(File.join(site.source, '_posts', '*', 'pic', '*'))
        
        asset_files.each do |asset_file|
          copy_single_asset(site, asset_file)
        end
      end

      # Copy a single asset file
      def self.copy_single_asset(site, asset_file)
        return unless File.file?(asset_file)
        
        post_info = extract_post_info(asset_file)
        return if post_info.nil?
        
        # Process asset name (remove .txt extension for placeholder files)
        asset_name = process_asset_name(File.basename(asset_file))
        
        # Create target path
        target_path = File.join(site.dest, 'posts', post_info[:slug], asset_name)
        
        # Copy asset
        Utils.copy_file_binary(asset_file, target_path)
        
        Jekyll.logger.info "Copying post asset: #{asset_name} for #{post_info[:name]}"
      end

      private

      # Extract post information from asset file path
      def self.extract_post_info(asset_file)
        post_dir = File.dirname(File.dirname(asset_file))
        post_name = File.basename(post_dir)
        post_slug = Utils.extract_post_slug(post_name)
        
        {
          dir: post_dir,
          name: post_name,
          slug: post_slug
        }
      rescue => e
        Jekyll.logger.error "Failed to extract post info from #{asset_file}: #{e.message}"
        nil
      end

      # Process asset name (handle placeholder files)
      def self.process_asset_name(asset_name)
        # Remove .txt extension if present (for placeholder files)
        if asset_name.end_with?('.txt')
          asset_name.chomp('.txt')
        else
          asset_name
        end
      end
    end
  end
end