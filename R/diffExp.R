#' @export
#' @importFrom    rhdf5 h5read H5close
#' @import RUVSeq edgeR DESeq2 EDASeq stats
#' @importFrom    dplyr everything left_join
#' @importFrom magrittr %>%
#' @importFrom ExperimentHub ExperimentHub
#' @importFrom Biobase pData
#' @importFrom utils globalVariables
#' @importFrom octad.db get_ExperimentHub_data
#' @importFrom utils write.csv data txtProgressBar read.csv2 head read.csv
#' @importFrom grDevices pdf
diffExp <- function(case_id = NULL, control_id = NULL, source = "octad.small", file = "octad.counts.and.tpm.h5",
    normalize_samples = TRUE, k = 1, expSet = NULL, n_topGenes = 500, DE_method = c("edgeR", "DESeq2", "wilcox",
        "limma"), output = FALSE, outputFolder = NULL, annotate = TRUE) {

    # STOPS
    DE_method <- match.arg(DE_method)

    if (DE_method == "DESeq2") {
        message("computing DE via DESeq2")
    } else if (DE_method == "edgeR") {
        message("computing DE via edgeR")
    } else if (DE_method == "limma") {
        message("computing DE via limma-voom")
    } else if (DE_method == "wilcox") {
        message("computing DE via wilcoxon rank-sum test")
    }

    if (missing(case_id)) {
        stop("Case ids vector input not found")
    }
    if (missing(case_id)) {
        stop("Case ids vector input not found")
    }

    # output check
    if (output == TRUE & is.null(outputFolder)) {
        outputFolder <- tempdir()
        message("outputFolder is NULL, writing output to tempdir()")
    } else if (output == TRUE & !is.null(outputFolder)) {
        if (output == TRUE & !dir.exists(outputFolder)) {
            dir.create(outputFolder)
        } else if (output == TRUE & dir.exists(outputFolder)) {
            warning("Existing directory ", outputFolder, " found, containtment might be overwritten")
        }
    }


    remLowExpr <- function(counts, counts_phenotype) {
        x <- DGEList(counts = round(counts), group = counts_phenotype$sample_type)
        cpm_x <- cpm(x)
        # needs to be at least larger the than the size of the smallest set
        keep.exprs <- rowSums(cpm_x > 1) >= min(table(counts_phenotype$sample_type))
        keep.exprs
    }



    if (missing(case_id) | missing(control_id)) {
        stop("Case ids and/or control ids vector input not found")
    }


    if (source == "octad.whole") {
        message("loading whole octad expression data for", length(c(case_id, control_id)), "samples", sep = " ")
        transcripts <- as.character(rhdf5::h5read(file, "meta/transcripts"))
        samples <- as.character(rhdf5::h5read(file, "meta/samples"))
        case_counts <- rhdf5::h5read(file, "data/count", index = list(seq_len(length(transcripts)), which(samples %in%
            case_id)))
        colnames(case_counts) <- samples[samples %in% case_id]
        rownames(case_counts) <- transcripts
        case_id <- samples[samples %in% case_id]
        normal_counts <- rhdf5::h5read(file, "data/count", index = list(seq_len(length(transcripts)), which(samples %in%
            control_id)))
        colnames(normal_counts) <- samples[samples %in% control_id]
        rownames(normal_counts) <- transcripts
        control_id <- samples[samples %in% control_id]
        H5close()

        expSet <- cbind(normal_counts, case_counts)
        rm(normal_counts)  # free up some memory
        rm(case_counts)
    } else if (source == "octad.small") {
        message("loading small octad set containing only expression for 978 LINCS genes")
        octad.LINCS.counts <- suppressMessages(get_ExperimentHub_data("EH7273"))
        expSet <- octad.LINCS.counts[, c(case_id, control_id)]
    } else if (source != "octad.small" & source != "octad.small" & missing(expSet)) {
        stop("Expression data not sourced, please, modify expSet option")
    }

    counts_phenotype <- rbind(data.frame(sample = case_id, sample_type = "case"), data.frame(sample = control_id,
        sample_type = "control"))
    counts_phenotype <- counts_phenotype[counts_phenotype$sample %in% colnames(expSet), ]
    counts <- expSet[, as.character(counts_phenotype$sample)]
    counts <- 2^counts - 1  # unlog the counts it was log(2x + 1) in dz.expr.log2.readCounts
    counts_phenotype$sample <- as.character(counts_phenotype$sample)
    counts_phenotype$sample_type <- factor(counts_phenotype$sample_type, levels = c("control", "case"))
    # remove lowly expressed transcripts
    highExpGenes <- remLowExpr(counts, counts_phenotype)
    counts <- counts[highExpGenes, ]
    set <- EDASeq::newSeqExpressionSet(round(counts), phenoData = data.frame(counts_phenotype, row.names = counts_phenotype$sample))

    # normalize samples using RUVSeq
    if (normalize_samples == TRUE) {
        # compute empirical genes
        design <- stats::model.matrix(~sample_type, data = Biobase::pData(set))
        y <- edgeR::DGEList(counts = counts(set), group = counts_phenotype$sample)
        y <- edgeR::calcNormFactors(y, method = "TMM")  # upperquartile generate Inf in the LGG case
        y <- edgeR::estimateGLMCommonDisp(y, design)
        y <- edgeR::estimateGLMTagwiseDisp(y, design)
        fit <- edgeR::glmFit(y, design)
        lrt <- edgeR::glmLRT(fit, 2)  # defaults to compare case control

        top <- edgeR::topTags(lrt, n = nrow(set))$table
        i <- which(!(rownames(set) %in% rownames(top)[seq_len(min(n_topGenes, dim(top)[1]))]))
        empirical <- rownames(set)[i]
        stopifnot(length(empirical) > 0)
        if (output == TRUE) {
            write.csv(data.frame(empirical), file = file.path(outputFolder, "computedEmpGenes.csv"))
        }
        set1 <- RUVSeq::RUVg(set, empirical, k = k)
    }

    if (DE_method == "DESeq2") {
        # library('DESeq2') message('computing DE via DESeq')
        row.names(counts_phenotype) <- counts_phenotype$sample
        coldata <- counts_phenotype
        if (normalize_samples == TRUE) {
            dds <- DESeq2::DESeqDataSetFromMatrix(countData = counts(set1), colData = Biobase::pData(set1), design = ~sample_type +
                W_1)
        } else {
            dds <- DESeq2::DESeqDataSetFromMatrix(countData = round(counts), colData = coldata, design = ~sample_type)
        }
        gc()
        dds <- DESeq2::DESeq(dds)


        rnms <- DESeq2::resultsNames(dds)
        resRaw <- DESeq2::results(dds, contrast = c("sample_type", "case", "control"))
        res <- data.frame(resRaw)
        res$identifier <- row.names(res)
    } else if (DE_method == "edgeR") {
        # message('computing DE via edgeR') construct model matrix based on whether there was normalization
        # ran
        if (normalize_samples == TRUE) {
            if (k == 1) {
                design <- stats::model.matrix(~sample_type + W_1, data = Biobase::pData(set1))
            } else if (k == 2) {
                design <- stats::model.matrix(~sample_type + W_1 + W_2, data = Biobase::pData(set1))
            } else if (k == 3) {
                design <- stats::model.matrix(~sample_type + W_1 + W_2 + W_3, data = Biobase::pData(set1))
            }
            dgList <- edgeR::DGEList(counts = counts(set1), group = set1$sample_type)
        } else {
            design <- stats::model.matrix(~sample_type, data = Biobase::pData(set))
            dgList <- edgeR::DGEList(counts = counts(set), group = set$sample_type)
        }
        dgList <- edgeR::calcNormFactors(dgList, method = "TMM")  # using upperquartile seems to give issue for LGG
        dgList <- edgeR::estimateGLMCommonDisp(dgList, design)
        dgList <- edgeR::estimateGLMTagwiseDisp(dgList, design)
        fit <- edgeR::glmFit(dgList, design)
        # see edgeRUsersGuide section on testing for DE genes for contrast
        lrt <- edgeR::glmLRT(fit, 2)
        # second coefficient otherwise it'll default the W_1 term when normalize is on
        res <- lrt$table
        colnames(res) <- c("log2FoldChange", "logCPM", "LR", "pvalue")
        res$padj <- p.adjust(res$pvalue)
        res$identifier <- row.names(res)
    } else if (DE_method == "limma") {
        # according to https://support.bioconductor.org/p/86461/, LIMMA + VOOM will not use normalized data
        message("computing DE via limma")
        x <- counts
        nsamples <- ncol(x)
        lcpm <- edgeR::cpm(x, log = TRUE)
        group <- counts_phenotype$sample_type
        design <- model.matrix(~0 + group)
        colnames(design) <- gsub("group", "", colnames(design))
        design <- as.data.frame(design)
        contr.matrix <- limma::makeContrasts(case - control, levels = colnames(design))

        v <- limma::voom(x, design, plot = FALSE)
        vfit <- limma::lmFit(v, design)
        vfit <- limma::contrasts.fit(vfit, contrasts = contr.matrix)
        efit <- limma::eBayes(vfit)

        tfit <- limma::treat(vfit, lfc = 1)  # not_sure
        dt <- limma::decideTests(tfit)
        summary(dt)

        tumorvsnormal <- limma::topTreat(tfit, coef = 1, n = Inf)
        tumorvsnormal <- tumorvsnormal[order(abs(tumorvsnormal$logFC), decreasing = TRUE), ]

        res <- tumorvsnormal
        colnames(res) <- c("log2FoldChange", "AveExpr", "t", "pvalue", "padj")
        res$identifier <- row.names(res)
    } else if (DE_method == "wilcox") {
        # adopt from https://rpubs.com/LiYumei/806213 where the author demonstrate wilcox is more
        # appropriate when sample size is large (n>10)
        y <- edgeR::DGEList(counts = counts(set), group = counts_phenotype$sample)
        keep <- edgeR::filterByExpr(y)
        y <- y[keep, keep.lib.sizes = FALSE]
        ## Perform TMM normalization and transfer to CPM (Counts Per Million)
        y <- edgeR::calcNormFactors(y, method = "TMM")
        count_norm <- edgeR::cpm(y)
        count_norm <- as.data.frame(count_norm)


        pvalues <- lapply(seq(from = 1, to = nrow(count_norm)), FUN = function(i) {
            data <- cbind.data.frame(gene = as.numeric(t(count_norm[i, ])), conditions = counts_phenotype$sample_type)
            p <- wilcox.test(gene ~ conditions, data)$p.value
            return(p)
        })
        fdr <- p.adjust(pvalues, method = "fdr")

        dataCon1 <- count_norm[, c(which(counts_phenotype$sample_type == "case"))]
        dataCon2 <- count_norm[, c(which(counts_phenotype$sample_type == "control"))]
        foldChanges <- log2(rowMeans(dataCon1)/rowMeans(dataCon2))
        res <- data.frame(log2FoldChange = foldChanges, pvalue = pvalues, padj = fdr)
        rownames(res) <- rownames(count_norm)
        res$identifier <- row.names(res)

    }
    if (annotate == TRUE) {
        merged_gene_info <- suppressMessages(get_ExperimentHub_data("EH7272"))
        merged_gene_info$ensembl <- as.vector(merged_gene_info$ensembl)
        merged_gene_info$V1 <- NULL  # modify it when will have time
        merged_gene_info$Symbol <- merged_gene_info$gene  # modify it when will have time
        merged_gene_info$gene <- NULL
        res <- left_join(res, merged_gene_info, by = c(identifier = "ensembl"))
    }
    return(res)
}
