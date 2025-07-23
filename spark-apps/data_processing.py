#!/usr/bin/env python3
"""
Example PySpark job for data processing
This script demonstrates:
- Reading data from S3 (LocalStack)
- Performing data transformations
- Writing results back to S3
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, max, min, when, isnan, isnull
import sys

def create_spark_session():
    """Create Spark session with S3 configuration"""
    return SparkSession.builder \
        .appName("DataProcessingJob") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .getOrCreate()

def read_data(spark, input_path):
    """Read data from S3"""
    print(f"Reading data from: {input_path}")
    
    # Read CSV data
    df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .csv(input_path)
    
    print(f"Data shape: {df.count()} rows, {len(df.columns)} columns")
    df.printSchema()
    
    return df

def clean_data(df):
    """Perform data cleaning operations"""
    print("Starting data cleaning...")
    
    # Remove rows with all null values
    df_clean = df.dropna(how='all')
    
    # Fill missing numeric values with median
    numeric_columns = [col_name for col_name, col_type in df_clean.dtypes 
                      if col_type in ['int', 'double', 'float']]
    
    for col_name in numeric_columns:
        median_val = df_clean.approxQuantile(col_name, [0.5], 0.01)[0]
        df_clean = df_clean.fillna({col_name: median_val})
    
    # Fill missing string values with 'Unknown'
    string_columns = [col_name for col_name, col_type in df_clean.dtypes 
                     if col_type == 'string']
    
    for col_name in string_columns:
        df_clean = df_clean.fillna({col_name: 'Unknown'})
    
    print(f"Data cleaning completed. Rows after cleaning: {df_clean.count()}")
    
    return df_clean

def analyze_data(df):
    """Perform data analysis"""
    print("Starting data analysis...")
    
    # Basic statistics
    numeric_columns = [col_name for col_name, col_type in df.dtypes 
                      if col_type in ['int', 'double', 'float']]
    
    if numeric_columns:
        stats_df = df.select([
            count(col(c)).alias(f"{c}_count"),
            avg(col(c)).alias(f"{c}_avg"),
            min(col(c)).alias(f"{c}_min"),
            max(col(c)).alias(f"{c}_max")
            for c in numeric_columns
        ])
        
        stats_df.show()
        return stats_df
    else:
        print("No numeric columns found for analysis")
        return df.limit(0)

def write_data(df, output_path):
    """Write processed data to S3"""
    print(f"Writing data to: {output_path}")
    
    df.coalesce(1) \
      .write \
      .mode("overwrite") \
      .option("header", "true") \
      .csv(output_path)
    
    print("Data written successfully")

def main():
    """Main execution function"""
    # Get command line arguments
    if len(sys.argv) < 3:
        print("Usage: spark-submit data_processing.py <input_path> <output_path>")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    # Create Spark session
    spark = create_spark_session()
    
    try:
        # Read data
        df = read_data(spark, input_path)
        
        # Clean data
        df_clean = clean_data(df)
        
        # Analyze data
        stats_df = analyze_data(df_clean)
        
        # Write processed data
        write_data(df_clean, output_path)
        
        # Write statistics
        stats_output_path = output_path.replace("/processed/", "/stats/")
        write_data(stats_df, stats_output_path)
        
        print("Data processing completed successfully!")
        
    except Exception as e:
        print(f"Error in data processing: {str(e)}")
        raise
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
