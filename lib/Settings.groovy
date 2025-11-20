import java.nio.file.Path
import java.nio.file.Paths

class Settings {
  //---------------------------------------------------------------------------------
  // Variables

  static Map PARAMS = null

  static final init(Map params) {
    PARAMS = params
  }

  static final rawParamValue(key) {
    if (key.indexOf(".") < 0) {
      return PARAMS.containsKey(key) ? PARAMS[key] : null;
    }

    def val = PARAMS

    for (sub_key in key.tokenize(".")) {
      if (!val.containsKey(sub_key)) return null;

      val = val[sub_key]
    }

    return val
  }

  static final ParamValue param(Map settings) {
    def key  = settings.key
    def type = settings.type
    def val  = rawParamValue(settings.key)

    if (settings.handler && val != null) {
      val = settings.handler(val)
    }

    if (val == null && settings.containsKey("default")) {
      return new ParamValue(settings.default)
    } else if (val == null && !settings.containsKey("default")) {
      throw new Exception("The required pipeline parameter '--${key} [${type.getSimpleName()}]' was not given")
    }

    if (type == File) {
      def file_val = new File(val)

      if (!file_val.exists()) {
        throw new Exception("The file of parameter '--${key} ${val}' does not exist")
      }

      return new ParamValue(file_val)
    }

    if (type == Directory) {
      def dir_val = new Directory(val)

      if (!dir_val.isDirectory()) {
        throw new Exception("The directory of parameter '--${key} ${val}' does not exist")
      }

      return new ParamValue(dir_val)
    }

    if (!type.isInstance(val)) {
      throw new Exception("Parameter '--${key} ${val}' " +
            "had wrong type, expected ${type.getSimpleName()}, " +
            "got ${val.getClass().getSimpleName()})")
    }

    if (!(settings.choices instanceof List)) {
      return new ParamValue(val)
    }

    if (!(val in settings.choices)) {
      throw new Exception("Parameter '--${key} ${val}' " +
            "was not among available choices: ${settings.choices.join(', ')}")
    }

    return new ParamValue(val)
  }

  static final ParamValue param(key, type) {
    return param(key: key, type: type)
  }
}
