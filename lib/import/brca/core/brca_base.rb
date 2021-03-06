require 'ndr_import/table'
require 'ndr_import/file/registry'
require 'json'
require 'pry'
require 'csv'

# folder = File.expand_path('../', __dir__)
# $LOAD_PATH.unshift(folder) unless $LOAD_PATH.include?(folder)


module Import
  module Brca
    module Core
      # Reads in pseudonymised BRCA data, then invokes processing method on each
      # record. This base can be extended so that processing is the full importer,
      # or only the corrections preprocessor and a csv writer
      class BrcaBase
        def initialize(filename, batch)
          @filename = filename
          @batch = batch
          @logger = Log.get_logger(batch.original_filename, batch.provider)
          @logger.info "Initialized import for #{@filename}"
          @logger.debug 'Available fields are: '
          fw = Import::Utility::PseudonymisedFileWrapper.new(@filename)
          fw.process
          fw.available_fields.each do |field|
            @logger.debug "\t#{field}"
          end
        end

        def load
          # ensure_file_not_already_loaded # TODO: PUT THIS BACK, TESTING ONLY
          tables = NdrImport::File::Registry.tables(@filename, table_mapping.try(:format), {})

          # Enumerate over the tables
          # Under normal circustances, there will only be one table
          tables.each do |_tablename, table_content|
            table_mapping.transform(table_content).each do |klass, fields, _index|
              Pseudo::Ppatient.transaction do
                process_records(klass, fields)
              end
            end
          end
        end

        private

        def file
          @file ||= SafeFile.exist?(@filename) ? SafeFile.new(@filename, 'r') : nil
        end

        # Load the required mapping file based on @batch.e_type
        def table_mapping
          # TODO: Decide on e_type names
          mapping_file = case @batch.e_type
                         when 'PSMOLE'
                           'brca_mapping.yml'
                         else
                           raise "No mapping found for #{@batch.e_type}"
                         end
          YAML.load_file(SafePath.new('mappings_config').join(mapping_file))
        end
      end
    end
  end
end
