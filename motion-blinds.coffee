# #Motion blinds

{ MotionGateway } = require 'motionblinds'
# ##The plugin code

# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an envirement object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # Include your own depencies with nodes global require function:
  #
  #     someThing = require 'someThing'
  #

  # ###MyPlugin classMotionBlinds # Create a class that extends the Plugin class and implements the following functions:
  class MotionBlindsPlugin extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins`
    #     section of the config.json file
    #
    #
    init: (app, @framework, @config) =>
      env.logger.info("Hello World", @config.apiKey)

      gw = new MotionGateway(@config.apiKey, 10)

      gw.on 'error', (err) =>
       env.logger.error(err)

      if @config.debug
        gw.on 'report', (report) =>
          env.logger.debug(report)

      gw.start()

      gw.getDeviceList().then( (devices) =>
          env.logger.info('devices', devices)
      ).catch( (err) -> env.logger.error err )

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("MotionShutterController", {
        configDef: deviceConfigDef.MotionShutterController,
        createCallback: (config, lastState) =>
          return new MotionShutterController(config, @framework, gw, lastState)
      })

      @framework.deviceManager.on('discover', (eventData) =>

        gw.getDeviceList().then( (devices) =>
          devices.data.forEach (d) =>
            if d.deviceType == MotionGateway.Blind
              displayName = "Motion Blind #{d.mac}"
              config = {
                class: 'MotionShutterController',
                name: displayName,
                mac: d.mac
              }
              @framework.deviceManager.discoveredDevice(
                'pimatic-motion-blinds', displayName, config
              )
        ).catch( (err) -> env.logger.error err )
      )

      @framework.on 'destroy', () => gw.stop()

    class MotionShutterController extends env.devices.ShutterController

      constructor: (@config, @framework, @gw, lastState) ->
        @name = @config.name
        @id = @config.id
        super()
        @_destroyed = false
        @_position = lastState?.position?.value or null
        @gw.on 'report', @_onReport

      destroy: () ->
        @_destroyed = true
        @gw.removeListener 'report', @_onReport
        super()

      _onReport: (info) =>
        env.logger.info 'report', info
        if info.mac != @config.mac
          return
        switch info.data.currentPosition
          when 0 then @_setPosition('up')
          when 100 then @_setPosition('down')
          else @_setPosition('stopped')

      getPosition: () ->
        return Promise.resolve @_position

      moveToPosition: (position) ->
        if @_destroyed
          return Promise.resolve()

        operation = (
          switch position
            when 'up' then MotionGateway.Operation.OpenUp
            when 'down' then MotionGateway.Operation.CloseDown
            when 'stopped' then MotionGateway.Operation.Stop
        )

        @gw.writeDevice(@config.mac, MotionGateway.Blind, {
          operation: operation,
        }).then () => @_setPosition position

      stop: () -> @moveToPosition("stopped")


  # ###Finally
  # Create a instance of my plugin
  motionBlindsPlugin = new MotionBlindsPlugin
  # and return it to the framework.
  return motionBlindsPlugin
