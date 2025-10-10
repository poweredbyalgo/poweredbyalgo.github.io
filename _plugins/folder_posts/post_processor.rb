#!/usr/bin/env ruby
#
# Post processor for folder-based posts
# This module handles reading and parsing content.md files within post folders

require_relative 'utils'

module Jekyll
  module FolderPosts
    module PostProcessor
      # Process all folder-based posts
      def self.process_folder_posts(site)
        content_files = Dir.glob(File.join(site.source, '_posts', '*', 'content.md'))
        
        content_files.each do |content_file|
          process_single_post(site, content_file)
        end
      end

      # Process a single folder-based post
      def self.process_single_post(site, content_file)
        post_dir = File.dirname(content_file)
        post_name = File.basename(post_dir)
        
        # Skip if a post for this folder already exists
        return if Utils.post_exists_for_folder?(site, post_dir)
        
        Jekyll.logger.info "Processing folder post: #{post_name}"
        
        # Read and parse content
        content = File.read(content_file)
        front_matter_text, post_content = Utils.split_content(content)
        
        if front_matter_text.nil?
          Jekyll.logger.warn "No valid front matter found in #{content_file}"
          return
        end
        
        # Parse YAML front matter
        data = Utils.parse_yaml_front_matter(front_matter_text, content_file)
        return if data.nil?
        
        # Create post document
        post = create_post_document(site, content_file, data, post_content, post_name)
        
        # Add to site posts
        site.collections['posts'].docs << post
      end

      private

      # Create a new post document with proper metadata
      def self.create_post_document(site, content_file, data, post_content, post_name)
        post = Jekyll::Document.new(content_file, {
          site: site,
          collection: site.collections['posts']
        })
        
        # Set post data
        post.data.merge!(data) if data
        post.content = post_content
        
        # Set required post metadata
        set_post_metadata(post, data, post_name, content_file)
        
        post
      end

      # Set post metadata including title, date, layout, etc.
      def self.set_post_metadata(post, data, post_name, content_file)
        # Set title
        post.data['title'] ||= data['title'] || Utils.extract_post_slug(post_name)
        
        # Set date
        set_post_date(post, data, post_name, content_file)
        
        # Set other metadata
        post.data['layout'] ||= 'post'
        post.data['slug'] ||= Utils.extract_post_slug(post_name)
        
        # Process tags and categories
        post.data['tags'] = Utils.normalize_array_data(post.data['tags'])
        post.data['categories'] = Utils.normalize_array_data(post.data['categories'])
      end

      # Set post date with fallback logic
      def self.set_post_date(post, data, post_name, content_file)
        if data && data['date']
          post.data['date'] = Utils.ensure_time_object(data['date'])
        else
          extracted_date = Utils.extract_date_from_path(post_name)
          if extracted_date
            post.data['date'] = Utils.ensure_time_object(extracted_date)
          else
            post.data['date'] = File.mtime(content_file)
          end
        end
      end
    end
  end
end