\name{octadDrugEnrichment}
\alias{octadDrugEnrichment}
\title{Compute Drug enrichment}
\description{
Perform enrichment analysis of drug hits based on chemical structures, drug-targets, and pharmacological classifications. An enrichment score calculated using ssGSEA and a p-value computed through a permutation test are provided. 
}
\usage{
  octadDrugEnrichment(sRGES = NULL, target_type = "chembl_targets",
  enrichFolder = "enrichFolder", outputFolder = NULL, outputRank = FALSE)

}
\arguments{
 \item{sRGES}{sRGES data frame produced by \code{runsRGES}.}
 \item{target_type}{one or several of \code{'chembl_targets','mesh','ChemCluster'} databases selected. By deafult only 'chembl_targets' will be used.}
 \item{enrichFolder}{folder to store output.}
 \item{outputFolder}{path where to store enrichFolder, in case of \code{NULL} will be stored in work directory.}
 \item{outputRank}{output detailed rank if \code{TRUE}, write sRGES for selected target as vcf.}
}
\value{
Following files are created: 
\code{enriched_*_targets.csv} and \code{top_enriched_*_*_targets.pdf}. In the case of chemical structural analysis, additional files are created: \code{*drugstructureClusters.csv} and \code{*misc.csv}. The results provide useful information for following candidate selection and experimental design. For example, if two structurally similar drugs are both predicted as top hits, the chance of each drug as a true positive is high.


\item{exprData}{\code{matrix} with either log2 corrected counts or tmp \code{matrix} for selected samples.}
}


\seealso{
  \code{\link{runsRGES}}
}
\examples{
data("sRGES_example",package='octad') #load example sRGES
#run drug enrichment 
octadDrugEnrichment(sRGES = sRGES_example, target_type = c('chembl_targets'))

}
\keyword{octadDrugEnrichment}
