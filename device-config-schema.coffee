# #Shell device configuration options
module.exports = {
  title: "pimatic-motion-blinds device config schemas"
  MotionShutterController: {
    title: "MotionShutterController config options"
    type: "object"
    extensions: ["xConfirm", "xLink"]
    properties:
      mac:
        description: "mac address as shown by the gateway as hax string"
        type: "string"
  }
}