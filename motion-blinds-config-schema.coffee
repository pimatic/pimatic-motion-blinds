# #motion-blinds configuration options
module.exports = {
  title: "my plugin config options"
  type: "object"
  properties:
    apiKey:
      description: "Motion Gateway APIKey"
      type: "string"
      required: true
}