#!/usr/bin/env ruby
#
# Main plugin file for folder-based post organization
# This plugin processes content.md files within post folders and manages their assets

require_relative 'folder_posts/utils'
require_relative 'folder_posts/post_processor'
require_relative 'folder_posts/asset_manager'
require_relative 'folder_posts/path_updater'

module Jekyll
  module FolderPosts
    # Hook to process folder-based posts before site post_read
    Jekyll::Hooks.register :site, :post_read do |site|
      PostProcessor.process_folder_posts(site)
    end
    
    # Hook to copy post folder assets and update image paths
    Jekyll::Hooks.register :site, :post_write do |site|
      AssetManager.copy_post_assets(site)
    end
    
    # Hook to update image paths in post content before rendering
    Jekyll::Hooks.register :posts, :pre_render do |post|
      PathUpdater.update_image_paths(post)
    end
  end
end