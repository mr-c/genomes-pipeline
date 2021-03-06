#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  cluster: Directory
  mash_files: File[]

outputs:
  prokka_faa-s:
    type: File[]
    outputSource: prokka/faa

  cluster_folder:
    type: Directory
    outputSource: create_cluster_folder/out
  roary_folder:
    type: Directory
    outputSource: return_roary_cluster_dir/pool_directory
  prokka_folder:
    type: Directory[]
    outputSource: return_prokka_cluster_dir/dir_of_dir
  genomes_folder:
    type: Directory
    outputSource: create_cluster_genomes/out

steps:
  preparation:
    run: ../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  prokka:
    run: ../../tools/prokka/prokka.cwl
    scatter: fa_file
    in:
      fa_file: preparation/files
      outdirname: {default: prokka_output }
    out: [ gff, faa, outdir ]

  roary:
    run: ../../tools/roary/roary.cwl
    in:
      gffs: prokka/gff
      roary_outfolder: {default: roary_output }
    out: [ pan_genome_reference-fa, roary_dir ]

  translate:
    run: ../../utils/translate_genes.cwl
    in:
      fa_file: roary/pan_genome_reference-fa
      faa_file:
        source: cluster
        valueFrom: $(self.basename)_pan_genome_reference.faa
    out: [ converted_faa ]

  IPS:
    run: ../../tools/IPS/InterProScan.cwl
    in:
      inputFile: translate/converted_faa
    out: [annotations]

  eggnog:
    run: ../../tools/eggnog/eggnog.cwl
    in:
      fasta_file: translate/converted_faa
      outputname:
        source: cluster
        valueFrom: $(self.basename)
    out: [annotations, seed_orthologs]
# --------------------------------------- result folder -----------------------------------------

  get_mash_file:
    run: ../../utils/get_file_pattern.cwl
    in:
      list_files: mash_files
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  create_cluster_folder:
    run: ../../utils/return_directory.cwl
    in:
      list:
        - translate/converted_faa
        - IPS/annotations
        - eggnog/annotations
        - eggnog/seed_orthologs
        - get_mash_file/file_pattern
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ out ]

  create_cluster_genomes:
    run: ../../utils/return_directory.cwl
    in:
      list: preparation/files
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)/genomes
    out: [ out ]

  return_prokka_cluster_dir:
    run: ../../utils/return_dir_of_dir.cwl
    scatter: directory
    in:
      directory: prokka/outdir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ dir_of_dir ]

  return_roary_cluster_dir:
    run: ../../utils/return_dir_of_dir.cwl
    in:
      directory_array:
        linkMerge: merge_nested
        source:
          - roary/roary_dir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ pool_directory ]