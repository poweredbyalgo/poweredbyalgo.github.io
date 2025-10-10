#!/usr/bin/env ruby
#
# Utility functions for folder-based post organization
# This module provides common utilities used across the folder posts plugin

require 'yaml'
require 'fileutils'

module Jekyll
  module FolderPosts
    module Utils
      # Extract date from folder path
      def self.extract_date_from_path(path)
        if path =~ /(\d{4})-(\d{2})-(\d{2})/
          Date.new($1.to_i, $2.to_i, $3.to_i)
        end
      end

      # Parse YAML front matter with error handling
      def self.parse_yaml_front_matter(front_matter_text, file_path)
        begin
          YAML.safe_load(front_matter_text, permitted_classes: [Date, Time])
        rescue => e
          Jekyll.logger.warn "Error parsing YAML in #{file_path}: #{e.message}"
          # Try with basic YAML parsing
          begin
            YAML.load(front_matter_text)
          rescue => e2
            Jekyll.logger.error "Failed to parse YAML in #{file_path}: #{e2.message}"
            nil
          end
        end
      end

      # Extract post slug from folder name
      def self.extract_post_slug(folder_name)
        folder_name.gsub(/\d{4}-\d{2}-\d{2}-/, '').gsub('-', ' ')
      end

      # Split content into front matter and content
      def self.split_content(content)
        if content =~ /\A(---\s*\n.*\n?)^---\s*\n\n?(.*)\z/m
          [$1, $2]
        else
          [nil, content]
        end
      end

      # Normalize array data (tags, categories)
      def self.normalize_array_data(data)
        return [] unless data
        Array(data).map(&:strip).reject(&:empty?)
      end

      # Convert Date to Time if needed
      def self.ensure_time_object(date_or_time)
        if date_or_time.is_a?(Date)
          Time.new(date_or_time.year, date_or_time.month, date_or_time.day)
        else
          date_or_time
        end
      end

      # Binary file copy to handle images correctly
      def self.copy_file_binary(source_path, target_path)
        FileUtils.mkdir_p(File.dirname(target_path))
        
        File.open(source_path, 'rb') do |source|
          File.open(target_path, 'wb') do |target|
            target.write(source.read)
          end
        end
      end

      # Check if a post already exists for the folder
      def self.post_exists_for_folder?(site, folder_path)
        site.posts.docs.any? { |post| File.dirname(post.path) == folder_path }
      end

      # Check if this is a folder-based post
      def self.folder_post?(post_path)
        post_path.include?('content.md')
      end
    end
  end
end