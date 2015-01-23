_ = require 'underscore'
UnselectedColumn = require './unselected-column'

module.exports = class AvailablePath extends UnselectedColumn

  # a function that will help us find the connected list, without
  # having a reverence to the parent directly.
  parameters: ['findActives']

  events: -> _.extend super,
    mousedown: 'onMouseDown'
    dragstart: 'onDragStart'
    dragstop: 'onDragStop'

  onMouseDown: ->
    @fixAppendTo()

  # Cannot be set correctly on init., since when this element is rendered
  # it is likely part of a document fragment, and thus its appendTo
  # will not be available.
  fixAppendTo: ->
    @$el.draggable 'option', 'appendTo', @$el.closest('.well')

  onDragStart: ->
    @state.set dragged: @model.get 'path'
    @$el.addClass 'ui-dragging'

  onDragStop: ->
    @state.unset 'dragged'
    @$el.removeClass 'ui-dragging'

  postRender: ->
    @$el.draggable
      axis: 'y'
      connectToSortable: @findActives()
      helper: 'clone'
      revert: 'invalid'
      opacity: 0.8
      cancel: 'i,a,button'
      zIndex: 1000
