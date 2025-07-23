name := "data-processing"

version := "1.0"

scalaVersion := "2.12.18"

val sparkVersion = "3.5.0"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql" % sparkVersion % "provided",
  "org.apache.hadoop" % "hadoop-aws" % "3.3.4" % "provided",
  "com.amazonaws" % "aws-java-sdk-bundle" % "1.12.262" % "provided"
)

// Assembly settings
assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case "application.conf" => MergeStrategy.concat
  case "reference.conf" => MergeStrategy.concat
  case _ => MergeStrategy.first
}

assembly / assemblyExcludedJars := {
  val cp = (assembly / fullClasspath).value
  cp filter { jar =>
    jar.data.getName.startsWith("spark-") ||
    jar.data.getName.startsWith("hadoop-") ||
    jar.data.getName.startsWith("scala-")
  }
}
