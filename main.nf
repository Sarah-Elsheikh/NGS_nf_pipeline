// first we set the default parameters
params.reference = null
params.data = null //this is the input
// sets a default out directory
params.out = "data_out"

// we run this with --out then specify the file in the console
// can test with these: nextflow run main.nf --data ERS20389616 --ref NC_000913.3
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

    def ch_input = channel.fromSRA(params.data)
        | view
    def ch_reference = channel.fromSRA(params.reference)
        | view
}

// this is a function to fetch the reference from the database
process fetch_reference {
    input:
    // here we need to add the accession number of the reference genome
    // we don't need to use a predefined $params.reference
    // we define here what we want to get 
    val accession  // as this is a value

    output:
    path "foo.txt"  // we create a text file as an output, that's why we need to use path 

    script:
    // at this point, we said that the input will be accession, which will come from $params.reference (defined in the workflow), 
    // but we still haven't made the connection (called the function) yet
    """
    esearch -db nucleotide -query "$accession" \\
        | efetch -format fasta > "${accession}.fasta"
    """
}