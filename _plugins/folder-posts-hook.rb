#!/usr/bin/env ruby
#
# Custom plugin to handle folder-based post organization
# This plugin processes content.md files within post folders

require 'yaml'
require 'fileutils'

module Jekyll
  # Hook to process folder-based posts before site post_read
  Jekyll::Hooks.register :site, :post_read do |site|
    # Process folder-based posts
    Dir.glob(File.join(site.source, '_posts', '*', 'content.md')).each do |content_file|
      post_dir = File.dirname(content_file)
      post_name = File.basename(post_dir)
      
      # Skip if a post for this folder already exists
      next if site.posts.docs.any? { |post| File.dirname(post.path) == post_dir }
      
      # Read content.md file
      content = File.read(content_file)
      
      # Parse front matter and content
      if content =~ /\A(---\s*\n.*\n?)^---\s*\n\n?(.*)\z/m
        front_matter_text = $1
        post_content = $2
        
        # Parse YAML front matter
        begin
          data = YAML.safe_load(front_matter_text, permitted_classes: [Date, Time])
        rescue => e
          Jekyll.logger.warn "Error parsing YAML in #{content_file}: #{e.message}"
          # Try with basic YAML parsing
          begin
            data = YAML.load(front_matter_text)
          rescue => e2
            Jekyll.logger.error "Failed to parse YAML in #{content_file}: #{e2.message}"
            next
          end
        end
        
        # Create a new post document
        post = Jekyll::Document.new(content_file, {
          site: site,
          collection: site.collections['posts']
        })
        
        # Set post data
        post.data.merge!(data) if data
        post.content = post_content
        
        # Set required post metadata
        post.data['title'] ||= data['title'] || post_name.gsub(/\d{4}-\d{2}-\d{2}-/, '').gsub('-', ' ')
        
        # Auto-set date: use date from front matter if provided, otherwise extract from folder name or use file creation time
        if data && data['date']
          post.data['date'] = data['date']
        else
          extracted_date = extract_date_from_path(post_name)
          # Convert Date to Time if needed
          if extracted_date.is_a?(Date)
            post.data['date'] = Time.new(extracted_date.year, extracted_date.month, extracted_date.day)
          else
            post.data['date'] = File.mtime(content_file)
          end
        end
        
        post.data['layout'] ||= 'post'
        post.data['slug'] ||= post_name.gsub(/\d{4}-\d{2}-\d{2}-/, '').gsub('-', ' ')
        
        # Process tags and categories
        if post.data['tags']
          post.data['tags'] = Array(post.data['tags']).map(&:strip).reject(&:empty?)
        end
        
        if post.data['categories']
          post.data['categories'] = Array(post.data['categories']).map(&:strip).reject(&:empty?)
        end
        
        # Add to site posts
        site.collections['posts'].docs << post
        
        Jekyll.logger.info "Processing folder post: #{post_name}"
      else
        Jekyll.logger.warn "No valid front matter found in #{content_file}"
      end
    end
  end
  
  def self.extract_date_from_path(path)
    if path =~ /(\d{4})-(\d{2})-(\d{2})/
      Date.new($1.to_i, $2.to_i, $3.to_i)
    end
  end
  
  # Hook to copy post folder assets and update image paths
  Jekyll::Hooks.register :site, :post_write do |site|
    # Copy assets from post folders to site
    Dir.glob(File.join(site.source, '_posts', '*', 'pic', '*')).each do |asset_file|
      next unless File.file?(asset_file)
      
      post_dir = File.dirname(File.dirname(asset_file))
      post_name = File.basename(post_dir)
      asset_name = File.basename(asset_file)
      
      # Remove .txt extension if present (for placeholder files)
      if asset_name.end_with?('.txt')
        asset_name = asset_name.chomp('.txt')
      end
      
      # Determine the post slug
      post_slug = post_name.gsub(/\d{4}-\d{2}-\d{2}-/, '').gsub('-', ' ')
      
      # Create target directory in the correct location
      target_dir = File.join(site.dest, 'posts', post_slug)
      FileUtils.mkdir_p(target_dir)
      
      # Copy asset using binary mode to avoid UTF-8 encoding issues
      target_file = File.join(target_dir, asset_name)
      
      # Use binary copy to handle image files correctly
      File.open(asset_file, 'rb') do |source|
        File.open(target_file, 'wb') do |target|
          target.write(source.read)
        end
      end
      
      Jekyll.logger.info "Copying post asset: #{asset_name} for #{post_name}"
    end
  end
  
  # Hook to update image paths in post content before rendering
  Jekyll::Hooks.register :posts, :pre_render do |post|
    # Only process folder-based posts
    if post.path.include?('content.md')
      # Determine the post slug
      post_dir = File.dirname(post.path)
      post_name = File.basename(post_dir)
      post_slug = post_name.gsub(/\d{4}-\d{2}-\d{2}-/, '').gsub('-', ' ')
      
      # Update image paths from pic/ to correct relative paths
      post.content = post.content.gsub(/!\[([^\]]*)\]\(pic\/([^\)]+)\)/) do |match|
        alt_text = $1
        image_name = $2
        "![#{alt_text}](/posts/#{post_slug}/#{image_name})"
      end
    end
  end
end