import java.nio.file.Path
import java.nio.file.Paths
import sun.nio.fs.UnixPath
import nextflow.Channel

class ParamValue {
  def value

  ParamValue(value) {
    this.value = value
  }

  def getChannel() {
    if (this.value instanceof File) {
      return Channel.fromPath(this.value)
    } else {
      return Channel.from(this.value)
    }
  }
}
