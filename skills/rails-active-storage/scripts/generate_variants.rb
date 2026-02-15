#!/usr/bin/env ruby

# Active Storage script to generate image variants
# Usage: ruby scripts/generate_variants.rb User avatar

require_relative "../config/environment"

class GenerateVariants
  def initialize(model_name, attachment_name)
    @model_name = model_name.classify
    @attachment_name = attachment_name
  end

  def run
    model_class = @model_name.constantize
    
    records = model_class.all
    total = records.count
    
    puts "Generating #{@attachment_name} variants for #{@model_name}..."
    puts "Processing #{total} records...\n"

    processed = 0
    errors = 0

    records.find_each.with_index do |record, index|
      begin
        attachment = record.public_send(@attachment_name)
        
        next unless attachment.attached?

        # Get all defined variants
        variants = get_variants(model_class, @attachment_name)
        
        variants.each do |variant_name|
          puts "  [#{index + 1}/#{total}] Generating #{variant_name} for #{record.id}..."
          
          variant = attachment.variant(variant_name)
          # Trigger generation
          variant.processed
          processed += 1
        end
      rescue => e
        puts "  [#{index + 1}/#{total}] Error: #{e.message}"
        errors += 1
      end
    end

    puts "\n✓ Complete!"
    puts "  - Processed: #{processed} variants"
    puts "  - Errors: #{errors}"
  end

  private

  def get_variants(model_class, attachment_name)
    # This is a simplified approach
    # In practice, you'd inspect the model's attachment config
    
    # For now, return common variants
    [:thumb, :medium, :large].select do |variant_name|
      begin
        model_class.new.public_send(attachment_name).respond_to?(:variant)
      rescue
        false
      end
    end
  end
end

if ARGV.length < 2
  puts "Usage: ruby scripts/generate_variants.rb <model_name> <attachment_name>"
  puts "Example: ruby scripts/generate_variants.rb User avatar"
  exit 1
end

generator = GenerateVariants.new(ARGV[0], ARGV[1])
generator.run
