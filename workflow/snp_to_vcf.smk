

rule vcf_header:
  input:
    vcf = "data/proto.vcf",
    genome = "data/sep_chr_1.genome"
  output:
    vcf = "results/vcf/header.vcf"
  params:
    date = datetime.datetime.today().strftime('%Y%m%d'),
    reference = "sep_chr_1.fa",
    species = '\\"dummy\\"'
  shell:
    """
    sed 's/XXgenomeXX/{params.reference}/; s/XXdateXX/{params.date}/' {input.vcf} > {output.vcf}
    awk '{{print "##contig=<ID="$1",length="$2",species={params.species}>"}}' {input.genome} >> {output.vcf}
    echo '##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">' >> {output.vcf}
    """

rule convert_scaf_vcf:
    input:
      tsv = "results/snps/{mscaf}.tsv"
    output:
      vcf = temp( "results/vcf/{mscaf}.vcf" )
    conda: "r_tidy"
    shell:
      """
      Rscript --vanilla R/snps_to_vcf.R {input.tsv} {output.vcf}
      """

rule combine_vcfs:
    input: 
      vcf_header = "results/vcf/header.vcf",
      vcf_body = expand( "results/vcf/{mscaf}.vcf", mscaf = SCFS )
    output:
      vcf = "results/vcf/genotpyes.vcf.gz"
    params:
      prefix = "results/vcf/genotpyes.vcf"
    shell:
      """
      cat {input.vcf_header} > {params.prefix}
      head -n 1 {input.vcf_body[0]} >> {params.prefix}
      tail -n +2 {input.vcf_body} | grep -v "==>" | grep -v "^$" >> {params.prefix}
      gzip {params.prefix}
      """

rule fst:
    input:
      vcf = "results/vcf/genotpyes.vcf.gz",
      pops = expand( "data/{p}.pop", p = [ "a", "b" ] )
    output:
      fst = "results/fst.tsv.gz"
    params:
      wsize = 1000,
      wstep = 500
    container: c_vcfh
    log: "logs/fst.log"
    shell:
      """
      vcftools_haploid \
        --haploid \
        --gzvcf {input.vcf} \
        --weir-fst-pop {input.pops[0]} \
        --weir-fst-pop {input.pops[1]} \
        --fst-window-size {params.wsize} \
        --fst-window-step {params.wstep} \
        --stdout 2> {log} | gzip > {output.fst}
      """
