// Sandro's:
// https://github.com/theneti3/nf-pipeline/tree/master
// run from github: nextflow run theneti3/nf-pipeline  --reference NC_000913.3 --data "data/samples/*_R{1,2}.fq"

// first we set the default parameters
params.reference = null
params.data = null //this is the input
// sets a default out directory
params.out = "data_out"

// we run this with --out then specify the file in the console
// can test with these: nextflow run main.nf (-with-conda) --data ERS20389616 --ref NC_000913.3
// -with-conda part we don't need to include if we have nextflow run -with-conda in config file
workflow {
    if (params.reference == null) {
        println ("reference NULL")
        exit 1
    }

    if (params.data == null) {
        println ("data NULL")
        exit 1
    }

    println("$params.reference, $params.data, $params.out")

    //def ch_input = channel.fromSRA(params.data, apiKey: "d5822ef54698cb072e0cf866736fd5f6ab08")
    //    | view

    def ch_input = fetch_data(params.data) 
    //    | view

    // now this is how we connect
    def ch_reference = fetch_reference(params.reference) 
    //    | view

    // we will use ch_input multiple times, so we define them here
    // we output 3 different channels in the output
    fastp(ch_input).sample_ID
        | view

    fastqc(ch_input)
        | view
}

/*
it seems it didn't work, so Fynn asked to do this in sequence:

cd ..
git clone https://github.com/FynnFreyer/nf-scripts
mv nf-scripts/data nf-pipeline/
rm -rf nf-scripts
cd nf-pipeline

def ch_input = channel.fromFilePairs(params.data) | view

run this in command line: --data "data/samples/*_R{1,2}.fq"
*/



// this is the function to fetch the reference from the database
process fetch_reference {
    // this is an alternative to conda if you have another container they contain the same environment. you need to install like docker
    // container "https://depot.galaxyproject.org/singularity/entrez-direct:24.0--he881be0_0"
    
    // this will run conda as esearch and efetch need bioconda
    conda "bioconda::entrez-direct=24.0"

    // publishDir "${params.out}/raw/"  // can set a directory

    input:
    // here we need to add the accession number of the reference genome
    // we don't need to use a predefined $params.reference
    // we define here what we want to get 
    val accession  // as this is a value

    output:
    path "${accession}.fasta"  // we create a text file as an output, that's why we need to use path 

    script:
    // at this point, we said that the input will be accession, which will come from $params.reference (defined in the workflow), 
    // but we still haven't made the connection (called the function) yet
    // here we redirect the efetch output to "${accession}.fasta"
    """
    esearch -db nucleotide -query "$accession" \\
        | efetch -format fasta > "${accession}.fasta"  
    """
}

process fetch_data {
    conda "bioconda::sra-tools=3.2.1"

    input:
    val sra_num

    output:
    path "*.fastq.gz"

    script:
    """
    prefetch "$sra_num"
    """
}


// Execute this
// conda config --add channels bioconda

// process to make fastp trimming
// we need to add a conda directive
process fastp {
//    conda "bioconda::fastp=1.1.0"
// doesn't seem to work, so run this:
// sudo apt install fastp
    input:
        val sample_data

    output:
        path "*.trimmed.fq.gz" , emit: sample_ID //tuple (val(sample_ID), path("*.trimmed.fq.gz)) suggested output name
        path "*.html" , emit: html_reports
        path "*.json" , emit: json_reports

    script:
    //unpack gz with groovey script
    // [sample_ID,[R1.R2]]
    
    sample_ID = sample_data[0]
    read1 = sample_data[1][0]
    read2 = sample_data[1][1]

    """
      
    fastp --in1 ${read1} --in2 ${read2} --out1 ${sample_ID}_R1.trimmed.fq.gz --out2 ${sample_ID}_R2.trimmed.fq.gz
    """
}


//process to fastqc
process fastqc{
    conda "bioconda::fastqc=0.12.1"

    input: 
        val fastq_data

    //tuple (val (fastq_data), path('*.fastq.gz'))

    output:
        path "fastqc_reports"

    script:
    sample_id = fastq_data[0]
    read1 = fastq_data[1][0]
    read2 = fastq_data[1][1]
    
    """
    fastqc ${read1} ${read2} --outdir fastqc_reports/${sample_id}.html
    """
}