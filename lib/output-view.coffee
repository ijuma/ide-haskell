{$, View} = require 'atom'
{ResultView} = require './result-view'
{ResultType} = require './util-data'

class OutputView extends View

  progressCounter: 0
  tabSwitchCounter: 0
  checkResults: []       # all results here

  @content: ->
    @div class: 'ide-haskell-panel', =>
      @div outlet: 'resizeHandle', class: 'resize-handle'
      @div class: 'panel', =>
        @div class: 'panel-heading', =>
          @div class: 'btn-toolbar pull-left', =>
            @div class: 'btn-group', =>
              @div outlet: 'statusIcon', class: 'status-icon'
            @div class: 'btn-group', =>
              @button click: 'switchTabView', outlet: 'errorsButton', class: 'btn tab-btn selected', id: 'tab1', 'Errors'
              @button click: 'switchTabView', outlet: 'warningsButton', class: 'btn tab-btn', id: 'tab2', 'Warnings'
            @div class: 'btn-group', =>
              @button click: 'switchTabView', outlet: 'lintsButton', class: 'btn tab-btn', id: 'tab3', 'Lints'
          @div class: 'btn-toolbar pull-right', =>
            @button outlet: 'closeButton', class: 'btn', 'Close'
        @div class: 'panel-body padding', =>
          @div class: 'tab-view', id: 'tab1', style: 'display: block;', =>
            @subview 'errorsListView', new ResultView()
          @div class: 'tab-view', id: 'tab2', style: 'display: none;', =>
            @subview 'warningsListView', new ResultView()
          @div class: 'tab-view', id: 'tab3', style: 'display: none;', =>
            @subview 'lintsListView', new ResultView()

  initialize: (state) ->
    @height state?.height
    if state?.isShow? then @toggle(state.isShow) else @toggle(true)

    # prepare arrays for errors, warnings and lints data
    @checkControl = [
      { v: @errorsListView, b: @errorsButton, t: @errorsButton.text() },
      { v: @warningsListView, b: @warningsButton, t: @warningsButton.text() },
      { v: @lintsListView, b: @lintsButton, t: @lintsButton.text() },
    ]

    # events
    @resizeHandle.on 'mousedown', (e) => @resizeStarted e
    @closeButton.on 'click', => @toggle()

  deactivate: ->
    @remove()

  serialize: ->
    height: @height()
    isShow: @isShow

  # toggle
  toggle: (isShow = undefined) ->
    if isShow? then @isShow = isShow else @isShow = not @isShow
    if @isShow then @attach() else @detach()

  # check and lint file
  checkFile: (checkFunction) ->
    fileName = atom.workspaceView.getActiveView()?.getEditor().getPath()
    return unless fileName?
    results = []

    checkFunction
      fileName: fileName
      onPrepare: (types) => @prepareResults(types)
      onResult: (result) -> results.push result
      onComplete: (types) => @updateResults(types, results)
      onFailure: => @updateResults(null)

  attach: ->
    atom.workspaceView.prependToBottom(this)

  resizeStarted: ({pageY}) =>
    @resizeData =
      pageY: pageY
      height: @height()
    $(document.body).on 'mousemove', @resizeView
    $(document.body).on 'mouseup', @resizeStopped

  resizeStopped: ->
    $(document.body).off 'mousemove', @resizeView
    $(document.body).off 'mouseup', @resizeStopped

  resizeView: ({pageY}) =>
    @height @resizeData.height + @resizeData.pageY - pageY

  switchTabView: (_, element) ->
    this.find('.btn.tab-btn').removeClass('selected')
    element.addClass('selected')
    this.find("div##{element[0].id}").show().siblings().hide()

  # method is called before start of any check commands
  prepareResults: (types) ->
    @tabSwitchCounter = @tabSwitchCounter + 1
    @backendActive()

  # update current results
  updateResults: (types = null, results = null) ->
    @tabSwitchCounter = @tabSwitchCounter - 1

    # do nothing if error
    if not types?
      @backendIdle()
      return

    @checkResults[t] = [] for t in types
    @checkResults[r.type].push(r) for r in results

    for t in types
      @checkControl[t].v.update @checkResults[t]
      @checkControl[t].b.text @buttonName(t)

    # update all opened editors with new results
    for editorView in atom.workspaceView.getEditorViews()
      @updateEditorView editorView, types, results

    @backendIdle()

    # automatic tab switching
    if atom.config.get('ide-haskell.switchTabOnCheck') and @tabSwitchCounter is 0
      for btn, t in @checkControl
        if @checkResults[t].length > 0
          @switchTabView null, btn.b
          break

  backendActive: ->
    @progressCounter = @progressCounter + 1
    if @progressCounter is 1
      @statusIcon.attr 'data-status', 'progress'

  backendIdle: (noError = true) ->
    @progressCounter = @progressCounter - 1
    if @progressCounter is 0
      if noError
        @statusIcon.attr 'data-status', 'ready'
      else
        @statusIcon.attr 'data-status', 'error'

  updateEditorView: (editorView, types = undefined, results = undefined) ->
    results = @checkResults unless results?
    editorView.haskellController.update types, results

  # get button name using results
  buttonName: (type) ->
    name = @checkControl[type].t
    count = @checkResults[type].length
    if count > 0 then "#{name} (#{count})" else "#{name}"


module.exports = {
  OutputView
}
