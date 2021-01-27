module Import
  module Helpers
    module Colorectal
      module Providers
        module Rq3
          # Processing methods used by BirminghamHandlerColorectal
          module Rq3Helper
            include Import::Helpers::Colorectal::Providers::Rq3::Rq3Constants

            def full_screen?(record)
              testscope = TEST_SCOPE_MAP_COLO_COLO[record.raw_fields['moleculartestingtype'].downcase.strip]
              testscope == :full_screen
            end

            def process_negative_genes(negativegenes, genotypes, genocolorectal)
              negativegenes.each do |negativegene|
                dup_genocolorectal = genocolorectal.dup_colo
                @logger.debug "Found #{negativegene} for list #{negativegenes}"
                dup_genocolorectal.add_status(1)
                dup_genocolorectal.add_gene_colorectal(negativegene)
                dup_genocolorectal.add_protein_impact(nil)
                dup_genocolorectal.add_gene_location(nil)
                genotypes.append(dup_genocolorectal)
              end
            end

            def positive_multiple_chromosomal_variants(positive_results, genotypes, genocolorectal)
              positive_results.each do |gene, chromosomalvariant|
                abnormal_genocolorectal = genocolorectal.dup_colo
                abnormal_genocolorectal.add_gene_colorectal(gene)
                abnormal_genocolorectal.add_status(2)
                abnormal_genocolorectal.add_variant_type(chromosomalvariant)
                genotypes.append(abnormal_genocolorectal)
              end
            end

            def positive_multiple_cdna_variants(positive_results, genotypes, genocolorectal)
              positive_results.each do |gene, cdna, protein|
                abnormal_genocolorectal = genocolorectal.dup_colo
                abnormal_genocolorectal.add_gene_colorectal(gene)
                abnormal_genocolorectal.add_gene_location(cdna)
                abnormal_genocolorectal.add_protein_impact(protein)
                abnormal_genocolorectal.add_status(2)
                genotypes.append(abnormal_genocolorectal)
              end
            end

            def process_mutyh_single_cdna_variants(genocolorectal, testresult, genotypes)
              genocolorectal.add_gene_colorectal('MUTYH')
              genocolorectal.add_gene_location(testresult.scan(CDNA_REGEX).join)
              genocolorectal.add_status(2)
              if testresult.scan(PROTEIN_REGEX).size.positive?
                genocolorectal.add_protein_impact(testresult.scan(PROTEIN_REGEX).join)
              end
              genotypes.append(genocolorectal)
            end

            def process_mutyh_specific_variants(testresult, genelist, genotypes, genocolorectal, record)
              if testresult.scan(CDNA_REGEX).size.positive?
                if testresult.scan(CDNA_REGEX).size == 1
                  process_mutyh_single_cdna_variants(genocolorectal, testresult, genotypes)
                  negativegenes = genelist - ['MUTYH']
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                elsif testresult.scan(CDNA_REGEX).size == 2
                  genes = ['MUTYH'] * testresult.scan(CDNA_REGEX).size
                  cdnas = testresult.scan(CDNA_REGEX).flatten
                  proteins = testresult.scan(PROTEIN_REGEX).flatten
                  positive_results = genes.zip(cdnas, proteins)
                  positive_multiple_cdna_variants(positive_results, genotypes, genocolorectal)
                  if full_screen?(record)
                    negativegenes = genelist - ['MUTYH']
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  end
                end
              else
                genocolorectal.add_gene_colorectal('MUTYH')
                genocolorectal.add_gene_location('')
                genocolorectal.add_status(2)
                genotypes.append(genocolorectal)
                if full_screen?(record)
                  negativegenes = genelist - ['MUTYH']
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                end
              end
            end

            def process_testreport_cdna_variants(testreport, genelist, genotypes, genocolorectal, record)
              if testreport.scan(CDNA_REGEX).size == 1
                if testreport.scan(COLORECTAL_GENES_REGEX).uniq.size == 1
                  genocolorectal.add_gene_colorectal(testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq.join)
                  genocolorectal.add_gene_location(testreport.scan(CDNA_REGEX).join)
                  genocolorectal.add_status(2)
                  if testreport.scan(PROTEIN_REGEX).size.positive?
                    genocolorectal.add_protein_impact(testreport.scan(PROTEIN_REGEX).join)
                  end
                  genotypes.append(genocolorectal)
                end
              elsif testreport.scan(CDNA_REGEX).size == 2
                if testreport.scan(COLORECTAL_GENES_REGEX).uniq.size == 2
                  genes = testreport.scan(COLORECTAL_GENES_REGEX).flatten
                  cdnas = testreport.scan(CDNA_REGEX).flatten
                  proteins = testreport.scan(PROTEIN_REGEX).flatten
                  positive_results = genes.zip(cdnas, proteins)
                  positive_multiple_cdna_variants(positive_results, genotypes, genocolorectal)
                end
              end
            end

            def process_malformed_variants(testresult, testreport, genelist, genotypes, genocolorectal, record)
              if (testresult =~ /FAP/ && testreport.scan(/APC/i).size.positive?) ||
                 (testresult =~ /High risk haplotype identified in this patient/ && testreport.scan(/APC/i).size.positive?)
                if full_screen?(record)
                  negativegenes = genelist - ['APC']
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                end
                genocolorectal.add_gene_colorectal('APC')
                genocolorectal.add_gene_location('')
                genocolorectal.add_status(2)
                genotypes.append(genocolorectal)
              elsif testreport.match(COLORECTAL_GENES_REGEX)
                gene = testreport.match(COLORECTAL_GENES_REGEX)[0]
                if full_screen?(record)
                  negativegenes = genelist - [gene]
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                end
                genocolorectal.add_gene_colorectal(gene)
                genocolorectal.add_gene_location('')
                genocolorectal.add_status(2)
                genotypes.append(genocolorectal)
              end
            end

            def process_testresult_cdna_variants(testresult, testreport, genelist, genotypes, record, genocolorectal)
              if testresult.scan(CDNA_REGEX).size == 1
                process_testresult_single_cdnavariant(testresult, testreport, record, genelist, genotypes, genocolorectal)
              elsif testresult.scan(CDNA_REGEX).size == 2
                process_testresult_multiple_cdnavariant(testresult, testreport, record, genelist, genotypes, genocolorectal)
              end
            end

            def process_chr_variants(record, testresult, testreport, genotypes, genocolorectal)
              if full_screen?(record)
                if sometimes_tested?(record)
                  genelist = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                  negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                else
                  negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                end
              end
              testcolumn = testresult
              process_chromosomal_variant(testcolumn, genelist, genotypes, record, genocolorectal)
            end

            def process_full_screen(record, testreport, genotypes, genocolorectal)
              if sometimes_tested?(record)
                genelist = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                process_negative_genes(negativegenes, genotypes, genocolorectal)
              else
                negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                process_negative_genes(negativegenes, genotypes, genocolorectal)
              end
            end

            def process_chromosomal_variant(testcolumn, genelist, genotypes, record, genocolorectal)
              if testcolumn.scan(COLORECTAL_GENES_REGEX).uniq.size == 1
                if testcolumn.scan(CHR_VARIANTS_REGEX).size == 1
                  genocolorectal.add_gene_colorectal(testcolumn.scan(COLORECTAL_GENES_REGEX).uniq.join)
                  genocolorectal.add_variant_type(testcolumn.scan(CHR_VARIANTS_REGEX).join)
                  genocolorectal.add_status(2)
                  genotypes.append(genocolorectal)
                else
                  genocolorectal.add_gene_colorectal(testcolumn.scan(COLORECTAL_GENES_REGEX).uniq.join)
                  genocolorectal.add_variant_type(testcolumn.scan(CHR_VARIANTS_REGEX)[1])
                  genocolorectal.add_status(2)
                  genotypes.append(genocolorectal)
                end
              elsif testcolumn.scan(COLORECTAL_GENES_REGEX).uniq.size > 1
                if testcolumn.scan(CHR_VARIANTS_REGEX).size == 1
                  genes = testcolumn.scan(COLORECTAL_GENES_REGEX).flatten
                  chromosomalvariants = testcolumn.scan(CHR_VARIANTS_REGEX).flatten * genes.size
                  positive_results = genes.zip(chromosomalvariants)
                  positive_multiple_chromosomal_variants(positive_results, genotypes, genocolorectal)
                else
                  genes = testcolumn.scan(COLORECTAL_GENES_REGEX).flatten
                  chromosomalvariants = testcolumn.scan(CHR_VARIANTS_REGEX).flatten
                  positive_results = genes.zip(chromosomalvariants)
                  positive_multiple_chromosomal_variants(positive_results, genotypes, genocolorectal)
                end
              end
            end

            def process_negative_records(genelist, genotypes, testresult,
                                         testreport, record, genocolorectal)
              @logger.debug 'NORMAL TEST FOUND'
              if full_screen?(record)
                if sometimes_tested?(record)
                  negativegenes = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                else
                  negativegenes = genelist
                  process_negative_genes(negativegenes, genotypes, genocolorectal)
                end
              elsif !full_screen?(record) && testreport.match(/MYH/i)
                negativegenes = ['MUTYH']
                process_negative_genes(negativegenes, genotypes, genocolorectal)
              else
                testresultgenes = testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                testreportgenes = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                negativegenes = testreportgenes.flatten.uniq
                process_negative_genes(negativegenes, genotypes, genocolorectal)
              end
            end

            def process_testresult_single_cdnavariant(testresult, testreport, record,
                                                      genelist, genotypes, genocolorectal)
              if testresult.scan(COLORECTAL_GENES_REGEX).uniq.size == 1
                if full_screen?(record)
                  if sometimes_tested?(record)
                    genelist = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  else
                    negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  end
                end
                genocolorectal.add_gene_colorectal(testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq.join)
                genocolorectal.add_gene_location(testresult.scan(CDNA_REGEX).join)
                genocolorectal.add_status(2)
                if testresult.scan(PROTEIN_REGEX).size.positive?
                  genocolorectal.add_protein_impact(testresult.scan(PROTEIN_REGEX).join)
                end
                genotypes.append(genocolorectal)
              else
                if full_screen?(record)
                  if sometimes_tested?(record)
                    genelist = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  else
                    negativegenes = genelist - [testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq[0]]
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  end
                end
                genocolorectal.add_gene_colorectal(testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq[0])
                genocolorectal.add_gene_location(testresult.scan(CDNA_REGEX).join)
                genocolorectal.add_status(2)
                if testresult.scan(PROTEIN_REGEX).size.positive?
                  genocolorectal.add_protein_impact(testresult.scan(PROTEIN_REGEX).join)
                end
                genotypes.append(genocolorectal)
              end
            end

            def sometimes_tested?(record)
              record.raw_fields['indication'] == 'HNPCC' ||
                record.raw_fields['indication'] == 'COLON' ||
                record.raw_fields['indication'] == 'NGS_COLON' ||
                record.raw_fields['indication'] == 'POLY'
            end

            def process_testresult_multiple_cdnavariant(testresult, testreport, record,
                                                        genelist, genotypes, genocolorectal)
              if testresult.scan(COLORECTAL_GENES_REGEX).uniq.size == 2
                if full_screen?(record)
                  if sometimes_tested?(record)
                    genelist = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  else
                    negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  end
                end
                genes = testresult.scan(COLORECTAL_GENES_REGEX).flatten
                cdnas = testresult.scan(CDNA_REGEX).flatten
                proteins = testresult.scan(PROTEIN_REGEX).flatten
                positive_results = genes.zip(cdnas, proteins)
                positive_multiple_cdna_variants(positive_results, genotypes, genocolorectal)
              elsif testresult.scan(COLORECTAL_GENES_REGEX).uniq.size == 1
                if full_screen?(record)
                  if sometimes_tested?(record)
                    genelist = testreport.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  else
                    negativegenes = genelist - testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq
                    process_negative_genes(negativegenes, genotypes, genocolorectal)
                  end
                end
                genes = testresult.scan(COLORECTAL_GENES_REGEX).flatten.uniq * 2
                cdnas = testresult.scan(CDNA_REGEX).flatten
                proteins = testresult.scan(PROTEIN_REGEX).flatten
                positive_results = genes.zip(cdnas, proteins)
                positive_multiple_cdna_variants(positive_results, genotypes, genocolorectal)
              end
            end
          end
        end
      end
    end
  end
end
