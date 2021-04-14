module Import
  module Helpers
    module Brca
      module Providers
        module Rq3
          module Rq3Constants
            PASS_THROUGH_FIELDS_COLO = %w[age sex consultantcode servicereportidentifier
                                          providercode authoriseddate receiveddate
                                          moleculartestingtype specimentype].freeze


            TEST_SCOPE_MAP_COLO_COLO = { '100kgp confirmation' => :full_screen,
                                         'confirmation' => :targeted_mutation,
                                         'diagnosis' => :full_screen,
                                         'family studies' => :targeted_mutation,
                                         'indirect testing' => :full_screen,
                                         'prenatal diagnosis' => :targeted_mutation,
                                         'presymptomatic' => :targeted_mutation,
                                         'ajp confirmation' => :aj_screen,
                                         'ajp screen' => :aj_screen
                                        }.freeze

            BRCA_GENES_MAP = { 'AZOVCA' => %w[BRCA1 BRCA2],
                               'BROV' => %w[BRCA1 BRCA2],
                               'BRCA' => %w[BRCA1 BRCA2 ATM CHEK2 PALB2 TP53] }.freeze


            REPORT_GENETICTESTSCOPE_REGEX = /previously identified in this family|previously reported in this family|previously found in an affected relative/i.freeze

            BRCA_REGEX = /(?<brca>BRCA(1|2)|PALB2|ATM|CHEK2|TP53)/i.freeze

            CDNA_REGEX = /c\.(?<cdna>([0-9]+[^[:alnum:]][0-9][^[:alnum:]][0-9]+
                          [^[:alnum:]][0-9][a-z]+)|
                          ([0-9]+[a-z]+[^[:alnum:]][a-z])|
                          ([0-9]+[^[:alnum:]][0-9]+[a-z]+[^[:alnum:]][a-z])|
                          ([0-9]+[a-z]+)|
                          ([0-9]+[^[:alnum:]][0-9]+[a-z]+)|
                          ([0-9]+[^[:alnum:]][0-9]+[^[:alnum:]][0-9]+[0-9]+[a-z]+))/ix.freeze

            PROTEIN_REGEX = /p\.(\()?((?<impact>.([a-z]+[0-9]+[a-z]+([^[:alnum:]][0-9]+)?)|
                             ([a-z]+[0-9]+[^[:alnum:]])))/ix .freeze

            CHR_VARIANTS_REGEX = /frameshift|
                                  truncation|
                                  insertion|
                                  deletion|
                                  duplication|
                                  missense|
                                  splice site|
                                  splice\-site|
                                  substitution|
                                  Splice site mutation|
                                  Nonsense/ix .freeze

            EXON_LOCATION_REGEX_COLO = /exons? (\d+[a-z]*(?: ?- ?\d+[a-z]*)?)/i.freeze
          end
        end
      end
    end
  end
end