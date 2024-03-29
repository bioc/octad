#'
#' Differential expression example for HCC vs adjacent liver tissue computed in diffExp() function
#' 
#' @format A data.frame with 963 rows and 18 variables:
#' \describe{
#'   \item{identifier}{Ensg ID}
#'   \item{log2FoldChange}{Log2 fold-change}
#'   \item{logCPM}{log CPM value}
#'   \item{LR}{LR value}
#'   \item{pvalue}{p.value}
#'   \item{padj }{FDR}
#'   \item{tax_id }{taxon id}
#'   \item{GeneID}{Gene id}
#'   \item{LocusTag}{Locus tag}
#'   \item{chromosome }{Chromosome}
#'   \item{map_location}{Chromosome location}
#'   \item{description}{Full gene name}
#'   \item{type}{type of gene}
#'   \item{Symbol_autho}{HGNC symbol}
#'   \item{other}{Gene function}
#' }
#'@details 
#'To generate this dataset use the following code from the octad package
#'#load data.frame with samples included in the OCTAD database.  \cr 
#'\code{phenoDF=.eh[['EH7274']]} \cr 
#'#select data \cr 
#'\code{HCC_primary=subset(phenoDF,cancer=='liver hepatocellular carcinoma'&sample.type == 'primary')} \cr 
#'#select cases \cr 
#'\code{case_id=HCC_primary$sample.id } \cr  
#'\code{control_id=subset(phenoDF,biopsy.site=='LIVER'&sample.type=='normal')$sample.id[1:50]} \cr 
#'\code{res=diffExp(case_id,control_id,source='octad.small',output=FALSE)} 
#'
#' @usage data(res_example)
'res_example'
