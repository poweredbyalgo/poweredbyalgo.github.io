#!/usr/bin/env ruby
#
# Path updater for folder-based posts
# This module handles updating image paths in post content

require_relative 'utils'

module Jekyll
  module FolderPosts
    module PathUpdater
      # Update image paths in post content
      def self.update_image_paths(post)
        # Only process folder-based posts
        return unless Utils.folder_post?(post.path)
        
        post_slug = extract_post_slug(post.path)
        
        # Update image paths from pic/ to correct relative paths
        post.content = update_content_image_paths(post.content, post_slug)
      end

      private

      # Extract post slug from post path
      def self.extract_post_slug(post_path)
        post_dir = File.dirname(post_path)
        post_name = File.basename(post_dir)
        Utils.extract_post_slug(post_name)
      end

      # Update image paths in content
      def self.update_content_image_paths(content, post_slug)
        # Pattern to match: ![alt text](pic/image.jpg)
        # Replace with: ![alt text](/posts/post-slug/image.jpg)
        content.gsub(/!\[([^\]]*)\]\(pic\/([^\)]+)\)/) do |match|
          alt_text = $1
          image_name = $2
          "![#{alt_text}](/posts/#{post_slug}/#{image_name})"
        end
      end
    end
  end
end