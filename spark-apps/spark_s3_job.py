#!/usr/bin/env python3
"""
PySpark Job for Sales Data Processing with S3 Integration
=========================================================

This PySpark job processes sales data from S3 and saves aggregated results back to S3.
Designed to work with SparkOperator on Kubernetes.
"""

import os
import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, avg, count, round as spark_round, max as spark_max, min as spark_min, lit
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType

def create_spark_session():
    """Create and configure Spark session with S3 support"""
    
    # Get environment variables
    aws_access_key = os.getenv("AWS_ACCESS_KEY_ID", "test")
    aws_secret_key = os.getenv("AWS_SECRET_ACCESS_KEY", "test")
    aws_endpoint = os.getenv("AWS_ENDPOINT_URL", "http://localstack-service.localstack.svc.cluster.local:4566")
    aws_region = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
    
    print(f"🔧 Configuring Spark with S3 endpoint: {aws_endpoint}")
    
    spark = SparkSession.builder \
        .appName("SalesDataProcessor") \
        .config("spark.hadoop.fs.s3a.endpoint", aws_endpoint) \
        .config("spark.hadoop.fs.s3a.access.key", aws_access_key) \
        .config("spark.hadoop.fs.s3a.secret.key", aws_secret_key) \
        .config("spark.hadoop.fs.s3a.path.style.access", "true") \
        .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false") \
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
        .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
        .getOrCreate()
    
    # Set log level to reduce verbosity but keep important info
    spark.sparkContext.setLogLevel("INFO")
    
    return spark

def read_sales_data(spark, input_path):
    """Read sales data from S3 with schema validation"""
    
    print(f"📊 Reading sales data from: {input_path}")
    
    # Define schema for better performance and data validation
    schema = StructType([
        StructField("transaction_id", StringType(), True),
        StructField("customer_id", StringType(), True),
        StructField("product_id", StringType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("unit_price", DoubleType(), True),
        StructField("transaction_date", StringType(), True),
        StructField("region", StringType(), True),
        StructField("product_category", StringType(), True),
        StructField("total_amount", DoubleType(), True)
    ])
    
    try:
        # Read JSON data with schema
        df = spark.read.schema(schema).json(input_path)
        
        # Validate data
        record_count = df.count()
        print(f"📈 Successfully loaded {record_count:,} sales records")
        
        if record_count == 0:
            raise ValueError("No data found in input path")
        
        # Show sample data
        print("📋 Sample data:")
        df.show(5, truncate=False)
        
        # Print schema
        print("📝 Data schema:")
        df.printSchema()
        
        return df
        
    except Exception as e:
        print(f"❌ Error reading data: {str(e)}")
        raise

def process_region_analysis(df, output_path):
    """Process and save regional sales analysis"""
    
    print("🌍 Processing regional sales analysis...")
    
    region_summary = df.groupBy("region") \
        .agg(
            spark_sum("total_amount").alias("total_revenue"),
            avg("total_amount").alias("avg_order_value"),
            count("transaction_id").alias("order_count"),
            spark_sum("quantity").alias("total_quantity"),
            spark_max("total_amount").alias("max_order_value"),
            spark_min("total_amount").alias("min_order_value")
        ) \
        .withColumn("avg_order_value", spark_round("avg_order_value", 2)) \
        .withColumn("total_revenue", spark_round("total_revenue", 2)) \
        .withColumn("max_order_value", spark_round("max_order_value", 2)) \
        .withColumn("min_order_value", spark_round("min_order_value", 2)) \
        .orderBy(col("total_revenue").desc())
    
    print("📊 Regional summary:")
    region_summary.show()
    
    # Save to S3
    print(f"💾 Saving regional analysis to: {output_path}")
    region_summary.coalesce(1).write.mode("overwrite").parquet(output_path)
    
    return region_summary

def process_category_analysis(df, output_path):
    """Process and save product category analysis"""
    
    print("📦 Processing product category analysis...")
    
    category_summary = df.groupBy("product_category") \
        .agg(
            spark_sum("total_amount").alias("total_revenue"),
            avg("total_amount").alias("avg_order_value"),
            count("transaction_id").alias("order_count"),
            spark_sum("quantity").alias("total_quantity"),
            avg("quantity").alias("avg_quantity_per_order")
        ) \
        .withColumn("avg_order_value", spark_round("avg_order_value", 2)) \
        .withColumn("total_revenue", spark_round("total_revenue", 2)) \
        .withColumn("avg_quantity_per_order", spark_round("avg_quantity_per_order", 2)) \
        .orderBy(col("total_revenue").desc())
    
    print("📊 Category summary:")
    category_summary.show()
    
    # Save to S3
    print(f"💾 Saving category analysis to: {output_path}")
    category_summary.coalesce(1).write.mode("overwrite").parquet(output_path)
    
    return category_summary

def process_customer_analysis(df, output_path):
    """Process and save top customers analysis"""
    
    print("� Processing customer analysis...")
    
    customer_summary = df.groupBy("customer_id") \
        .agg(
            spark_sum("total_amount").alias("total_spent"),
            count("transaction_id").alias("transaction_count"),
            avg("total_amount").alias("avg_order_value"),
            spark_sum("quantity").alias("total_items_purchased")
        ) \
        .withColumn("avg_order_value", spark_round("avg_order_value", 2)) \
        .withColumn("total_spent", spark_round("total_spent", 2)) \
        .orderBy(col("total_spent").desc()) \
        .limit(50)  # Top 50 customers
    
    print("📊 Top customers:")
    customer_summary.show(10)
    
    # Save to S3
    print(f"💾 Saving customer analysis to: {output_path}")
    customer_summary.coalesce(1).write.mode("overwrite").parquet(output_path)
    
    return customer_summary

def process_daily_metrics(df, output_path):
    """Process and save daily metrics summary"""
    
    print("📅 Processing daily metrics...")
    
    # Get the processing date (should be the same for all records)
    processing_date = df.select("transaction_date").first()[0]
    
    daily_summary = df.agg(
        count("transaction_id").alias("total_transactions"),
        spark_sum("total_amount").alias("total_revenue"),
        avg("total_amount").alias("avg_transaction_value"),
        spark_sum("quantity").alias("total_items_sold")
    ).withColumn("avg_transaction_value", spark_round("avg_transaction_value", 2)) \
     .withColumn("total_revenue", spark_round("total_revenue", 2)) \
     .withColumn("processing_date", lit(processing_date))
    
    print("📊 Daily metrics:")
    daily_summary.show()
    
    # Save to S3
    print(f"💾 Saving daily metrics to: {output_path}")
    daily_summary.coalesce(1).write.mode("overwrite").parquet(output_path)
    
    return daily_summary

def main():
    """Main PySpark job execution"""
    
    print("� Starting PySpark Sales Data Processing Job...")
    print(f"🔧 Python version: {sys.version}")
    
    # Initialize Spark session
    spark = create_spark_session()
    
    try:
        # Configure paths
        bucket_name = "data-engineering-bucket"
        input_path = f"s3a://{bucket_name}/spark-input/sales/"
        base_output_path = f"s3a://{bucket_name}/spark-output"
        
        print(f"📂 Input path: {input_path}")
        print(f"📂 Output base path: {base_output_path}")
        
        # Read input data
        df = read_sales_data(spark, input_path)
        
        # Cache the dataframe since we'll use it multiple times
        df.cache()
        
        # Process different analyses
        region_analysis = process_region_analysis(
            df, f"{base_output_path}/aggregations/region_summary/"
        )
        
        category_analysis = process_category_analysis(
            df, f"{base_output_path}/aggregations/category_summary/"
        )
        
        customer_analysis = process_customer_analysis(
            df, f"{base_output_path}/analytics/top_customers/"
        )
        
        daily_metrics = process_daily_metrics(
            df, f"{base_output_path}/metrics/daily_summary/"
        )
        
        # Generate final summary statistics
        total_records = df.count()
        total_revenue = df.agg(spark_sum("total_amount")).collect()[0][0]
        unique_customers = df.select("customer_id").distinct().count()
        unique_products = df.select("product_id").distinct().count()
        unique_regions = df.select("region").distinct().count()
        unique_categories = df.select("product_category").distinct().count()
        
        print(f"""
✅ PySpark Job Completed Successfully!

📊 Processing Summary:
   • Total Records Processed: {total_records:,}
   • Total Revenue: ${total_revenue:,.2f}
   • Unique Customers: {unique_customers:,}
   • Unique Products: {unique_products:,}
   • Unique Regions: {unique_regions:,}
   • Unique Categories: {unique_categories:,}

📁 Output Files Created:
   • Regional Analysis: {base_output_path}/aggregations/region_summary/
   • Category Analysis: {base_output_path}/aggregations/category_summary/
   • Customer Analysis: {base_output_path}/analytics/top_customers/
   • Daily Metrics: {base_output_path}/metrics/daily_summary/

🎉 All analyses completed and saved to S3!
        """)
        
    except Exception as e:
        print(f"❌ Error in PySpark job: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    
    finally:
        # Stop Spark session
        print("🔚 Stopping Spark session...")
        spark.stop()

if __name__ == "__main__":
    main()
