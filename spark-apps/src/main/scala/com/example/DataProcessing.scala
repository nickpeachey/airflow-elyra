package com.example

import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._

/**
 * Scala Spark Data Processing Application
 * 
 * This application demonstrates:
 * - Reading data from S3 (LocalStack)
 * - Performing data transformations
 * - Writing results back to S3
 * 
 * Usage: spark-submit --class com.example.DataProcessing data-processing_2.12-1.0.jar <input-path> <output-path>
 */
object DataProcessing {
  
  def main(args: Array[String]): Unit = {
    if (args.length < 2) {
      println("Usage: DataProcessing <input-path> <output-path>")
      System.exit(1)
    }
    
    val inputPath = args(0)
    val outputPath = args(1)
    
    // Create Spark session
    val spark = SparkSession.builder()
      .appName("ScalaDataProcessing")
      .config("spark.sql.adaptive.enabled", "true")
      .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
      .getOrCreate()
    
    import spark.implicits._
    
    try {
      println(s"Reading data from: $inputPath")
      
      // Read data
      val df = readData(spark, inputPath)
      
      // Process data
      val processedDF = processData(df)
      
      // Write results
      writeData(processedDF, outputPath)
      
      // Generate statistics
      generateStatistics(processedDF, outputPath)
      
      println("Data processing completed successfully!")
      
    } catch {
      case e: Exception =>
        println(s"Error in data processing: ${e.getMessage}")
        e.printStackTrace()
        throw e
    } finally {
      spark.stop()
    }
  }
  
  /**
   * Read data from input path
   */
  def readData(spark: SparkSession, inputPath: String): DataFrame = {
    println(s"Reading data from: $inputPath")
    
    val df = spark.read
      .option("header", "true")
      .option("inferSchema", "true")
      .csv(inputPath)
    
    println(s"Data shape: ${df.count()} rows, ${df.columns.length} columns")
    df.printSchema()
    
    df
  }
  
  /**
   * Process and clean the data
   */
  def processData(df: DataFrame): DataFrame = {
    println("Starting data processing...")
    
    // Remove rows with all null values
    val cleanDF = df.na.drop("all")
    
    // Get numeric columns
    val numericColumns = df.dtypes
      .filter { case (_, dataType) => 
        dataType == "IntegerType" || dataType == "DoubleType" || dataType == "FloatType" || dataType == "LongType"
      }
      .map(_._1)
    
    // Fill missing numeric values with median
    val filledDF = numericColumns.foldLeft(cleanDF) { (tempDF, colName) =>
      val medianValue = tempDF.stat.approxQuantile(colName, Array(0.5), 0.01).head
      tempDF.na.fill(medianValue, Seq(colName))
    }
    
    // Fill missing string values
    val stringColumns = df.dtypes
      .filter(_._2 == "StringType")
      .map(_._1)
    
    val finalDF = stringColumns.foldLeft(filledDF) { (tempDF, colName) =>
      tempDF.na.fill("Unknown", Seq(colName))
    }
    
    // Add processing metadata
    val processedDF = finalDF
      .withColumn("processing_timestamp", current_timestamp())
      .withColumn("processing_date", current_date())
    
    println(s"Data processing completed. Rows after processing: ${processedDF.count()}")
    
    processedDF
  }
  
  /**
   * Write processed data to output path
   */
  def writeData(df: DataFrame, outputPath: String): Unit = {
    println(s"Writing data to: $outputPath")
    
    df.coalesce(1)
      .write
      .mode("overwrite")
      .option("header", "true")
      .csv(outputPath)
    
    println("Data written successfully")
  }
  
  /**
   * Generate and save statistics
   */
  def generateStatistics(df: DataFrame, outputPath: String): Unit = {
    println("Generating statistics...")
    
    // Basic statistics
    val rowCount = df.count()
    val columnCount = df.columns.length
    
    // Get numeric columns for statistics
    val numericColumns = df.dtypes
      .filter { case (_, dataType) => 
        dataType == "IntegerType" || dataType == "DoubleType" || dataType == "FloatType" || dataType == "LongType"
      }
      .map(_._1)
    
    // Calculate statistics for numeric columns
    val statisticsDF = if (numericColumns.nonEmpty) {
      val statsExprs = numericColumns.flatMap { col =>
        Seq(
          count(df(col)).alias(s"${col}_count"),
          avg(df(col)).alias(s"${col}_avg"),
          min(df(col)).alias(s"${col}_min"),
          max(df(col)).alias(s"${col}_max"),
          stddev(df(col)).alias(s"${col}_stddev")
        )
      }
      
      df.agg(statsExprs.head, statsExprs.tail: _*)
    } else {
      // Create empty statistics DataFrame if no numeric columns
      df.limit(0)
    }
    
    // Show statistics
    statisticsDF.show()
    
    // Write statistics
    val statsOutputPath = outputPath.replace("/processed/", "/stats/")
    statisticsDF.coalesce(1)
      .write
      .mode("overwrite")
      .option("header", "true")
      .csv(statsOutputPath)
    
    // Generate summary report
    val summary = Map(
      "total_rows" -> rowCount,
      "total_columns" -> columnCount,
      "numeric_columns" -> numericColumns.length,
      "processing_timestamp" -> java.time.Instant.now().toString
    )
    
    println("Processing Summary:")
    summary.foreach { case (key, value) => println(s"  $key: $value") }
  }
}
