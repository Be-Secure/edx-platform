if not @Discussion?
  @Discussion = {}

Discussion = @Discussion

initializeVote = (content) ->
  $content = $(content)
  $local = Discussion.generateLocal($content.children(".discussion-content"))
  id = $content.attr("_id")
  if Discussion.isUpvoted id
    $local(".discussion-vote-up").addClass("voted")
  else if Discussion.isDownvoted id
    $local(".discussion-vote-down").addClass("voted")

initializeFollowThread = (thread) ->
  $thread = $(thread)
  id = $thread.attr("_id")
  $thread.children(".discussion-content")
         .find(".follow-wrapper")
         .append(Discussion.subscriptionLink('thread', id))

@Discussion = $.extend @Discussion,

  bindContentEvents: (content) ->

    $content = $(content)
    $discussionContent = $content.children(".discussion-content")
    $local = Discussion.generateLocal($discussionContent)

    id = $content.attr("_id")

    handleReply = (elem) ->
      $replyView = $local(".discussion-reply-new")
      if $replyView.length
        $replyView.show()
      else
        thread_id = $discussionContent.parents(".thread").attr("_id")
        view =
          id: id
          showWatchCheckbox: not Discussion.isSubscribed(thread_id, "thread")
        $discussionContent.append Mustache.render Discussion.replyTemplate, view
        Discussion.makeWmdEditor $content, $local, "reply-body"
        $local(".discussion-submit-post").click -> handleSubmitReply(this)
        $local(".discussion-cancel-post").click -> handleCancelReply(this)
      $local(".discussion-reply").hide()
      $local(".discussion-edit").hide()

    handleCancelReply = (elem) ->
      $replyView = $local(".discussion-reply-new")
      if $replyView.length
        $replyView.hide()
      $local(".discussion-reply").show()
      $local(".discussion-edit").show()

    handleSubmitReply = (elem) ->
      if $content.hasClass("thread")
        url = Discussion.urlFor('create_comment', id)
      else if $content.hasClass("comment")
        url = Discussion.urlFor('create_sub_comment', id)
      else
        return

      body = Discussion.getWmdContent $content, $local, "reply-body"

      anonymous = false || $local(".discussion-post-anonymously").is(":checked")
      autowatch = false || $local(".discussion-auto-watch").is(":checked")

      Discussion.safeAjax
        $elem: $(elem)
        url: url
        type: "POST"
        dataType: 'json'
        data:
          body: body
          anonymous: anonymous
          autowatch: autowatch
        success: Discussion.formErrorHandler($local(".discussion-errors"), (response, textStatus) ->
          $comment = $(response.html)
          $content.children(".comments").prepend($comment)
          Discussion.setWmdContent $content, $local, "reply-body", ""
          Discussion.setContentInfo response.content['id'], 'editable', true
          Discussion.initializeContent($comment)
          Discussion.bindContentEvents($comment)
          $local(".discussion-reply-new").hide()
          $local(".discussion-reply").show()
          $local(".discussion-edit").show()
          $discussionContent.attr("status", "normal")
        )

    handleVote = (elem, value) ->
      contentType = if $content.hasClass("thread") then "thread" else "comment"
      url = Discussion.urlFor("#{value}vote_#{contentType}", id)
      Discussion.safeAjax
        $elem: $local(".discussion-vote")
        url: url
        type: "POST"
        dataType: "json"
        success: (response, textStatus) ->
          if textStatus == "success"
            $local(".discussion-vote").removeClass("voted")
            $local(".discussion-vote-#{value}").addClass("voted")
            $local(".discussion-votes-point").html response.votes.point

    handleUnvote = (elem, value) ->
      contentType = if $content.hasClass("thread") then "thread" else "comment"
      url = Discussion.urlFor("undo_vote_for_#{contentType}", id)
      Discussion.safeAjax
        $elem: $local(".discussion-vote")
        url: url
        type: "POST"
        dataType: "json"
        success: (response, textStatus) ->
          if textStatus == "success"
            $local(".discussion-vote").removeClass("voted")
            $local(".discussion-votes-point").html response.votes.point

    handleCancelEdit = (elem) ->
      $local(".discussion-content-edit").hide()
      $local(".discussion-content-wrapper").show()

    handleEditThread = (elem) ->
      $local(".discussion-content-wrapper").hide()
      $editView = $local(".discussion-content-edit")
      if $editView.length
        $editView.show()
      else
        view = {
          id: id
          title: $local(".thread-title").html()
          body: $local(".thread-raw-body").html()
          tags: $local(".thread-raw-tags").html()
        }
        $discussionContent.append Mustache.render Discussion.editThreadTemplate, view
        Discussion.makeWmdEditor $content, $local, "thread-body-edit"
        $local(".thread-tags-edit").tagsInput Discussion.tagsInputOptions()
        $local(".discussion-submit-update").unbind("click").click -> handleSubmitEditThread(this)
        $local(".discussion-cancel-update").unbind("click").click -> handleCancelEdit(this)

    handleSubmitEditThread = (elem) ->
      url = Discussion.urlFor('update_thread', id)
      title = $local(".thread-title-edit").val()
      body = Discussion.getWmdContent $content, $local, "thread-body-edit"
      tags = $local(".thread-tags-edit").val()
      Discussion.safeAjax
        $elem: $(elem)
        url: url
        type: "POST"
        dataType: 'json'
        data: {title: title, body: body, tags: tags},
        success: Discussion.formErrorHandler($local(".discussion-update-errors"), (response, textStatus) ->
          $discussionContent.replaceWith(response.html)
          Discussion.initializeContent($content)
          Discussion.bindContentEvents($content)
        )

    handleEditComment = (elem) ->
      $local(".discussion-content-wrapper").hide()
      $editView = $local(".discussion-content-edit")
      if $editView.length
        $editView.show()
      else
        view = { id: id, body: $local(".comment-raw-body").html() }
        $discussionContent.append Mustache.render Discussion.editCommentTemplate, view
        Discussion.makeWmdEditor $content, $local, "comment-body-edit"
        $local(".discussion-submit-update").unbind("click").click -> handleSubmitEditComment(this)
        $local(".discussion-cancel-update").unbind("click").click -> handleCancelEdit(this)

    handleSubmitEditComment= (elem) ->
      url = Discussion.urlFor('update_comment', id)
      body = Discussion.getWmdContent $content, $local, "comment-body-edit"
      Discussion.safeAjax
        $elem: $(elem)
        url: url
        type: "POST"
        dataType: "json"
        data: {body: body}
        success: Discussion.formErrorHandler($local(".discussion-update-errors"), (response, textStatus) ->
          $discussionContent.replaceWith(response.html)
          Discussion.initializeContent($content)
          Discussion.bindContentEvents($content)
        )

    handleEndorse = (elem, endorsed) ->
      url = Discussion.urlFor('endorse_comment', id)
      Discussion.safeAjax
        $elem: $(elem)
        url: url
        type: "POST"
        dataType: "json"
        data: {endorsed: endorsed}
        success: (response, textStatus) ->
          if textStatus == "success"
            if endorsed
              $(content).addClass("endorsed")
            else
              $(content).removeClass("endorsed")

    handleHideSingleThread = (elem) ->
      $threadTitle = $local(".thread-title")
      $showComments = $local(".discussion-show-comments")
      $content.children(".comments").hide()
      $threadTitle.unbind('click').click handleShowSingleThread
      $showComments.unbind('click').click handleShowSingleThread
      prevHtml = $showComments.html()
      $showComments.html prevHtml.replace "Hide", "Show"

    handleShowSingleThread = ->
      $threadTitle = $local(".thread-title")
      $showComments = $local(".discussion-show-comments")

      if not $showComments.length or not $threadTitle.length
        return

      rebindHideEvents = ->
        $threadTitle.unbind('click').click handleHideSingleThread
        $showComments.unbind('click').click handleHideSingleThread
        prevHtml = $showComments.html()
        $showComments.html prevHtml.replace "Show", "Hide"

      if $content.children(".comments").length
        $content.children(".comments").show()
        rebindHideEvents()
      else
        discussion_id = $threadTitle.parents(".discussion").attr("_id")
        url = Discussion.urlFor('retrieve_single_thread', discussion_id, id)
        Discussion.safeAjax
          $elem: $.merge($threadTitle, $showComments)
          url: url
          type: "GET"
          dataType: 'json'
          success: (response, textStatus) ->
            Discussion.bulkExtendContentInfo response['annotated_content_info']
            $content.append(response['html'])
            $content.find(".comment").each (index, comment) ->
              Discussion.initializeContent(comment)
              Discussion.bindContentEvents(comment)
            rebindHideEvents()
      
    Discussion.bindLocalEvents $local,

      "click .thread-title": ->
        handleShowSingleThread(this)

      "click .discussion-show-comments": ->
        handleShowSingleThread(this)

      "click .discussion-reply-thread": ->
        handleShowSingleThread($local(".thread-title"))
        handleReply(this)

      "click .discussion-reply-comment": ->
        handleReply(this)

      "click .discussion-cancel-reply": ->
        handleCancelReply(this)

      "click .discussion-vote-up": ->
        $elem = $(this)
        if $elem.hasClass("voted")
          handleUnvote($elem)
        else
          handleVote($elem, "up")

      "click .discussion-vote-down": ->
        $elem = $(this)
        if $elem.hasClass("voted")
          handleUnvote($elem)
        else
          handleVote($elem, "down")

      "click .discussion-endorse": ->
        handleEndorse(this, $(this).is(":checked"))

      "click .discussion-edit": ->
        if $content.hasClass("thread")
          handleEditThread(this)
        else
          handleEditComment(this)

  initializeContent: (content) ->

    unescapeHighlightTag = (text) ->
      text.replace(/\&lt\;highlight\&gt\;/g, "<span class='search-highlight'>")
          .replace(/\&lt\;\/highlight\&gt\;/g, "</span>")

    stripHighlight = (text, type) ->
      text.replace(/\&(amp\;)?lt\;highlight\&(amp\;)?gt\;/g, "")
          .replace(/\&(amp\;)?lt\;\/highlight\&(amp\;)?gt\;/g, "")


    stripLatexHighlight = (text) ->
      Discussion.processEachMathAndCode text, stripHighlight

    markdownWithHighlight = (text) ->
      converter = Markdown.getMathCompatibleConverter()
      unescapeHighlightTag stripLatexHighlight converter.makeHtml text

    $content = $(content)
    initializeVote $content
    if $content.hasClass("thread")
      initializeFollowThread $content
    $local = Discussion.generateLocal($content.children(".discussion-content"))

    $contentTitle = $local(".thread-title")

    if $contentTitle.length
      $contentTitle.html unescapeHighlightTag stripLatexHighlight $contentTitle.html()

    $contentBody = $local(".content-body")

    $contentBody.html Discussion.postMathJaxProcessor markdownWithHighlight $contentBody.html()

    MathJax.Hub.Queue ["Typeset", MathJax.Hub, $contentBody.attr("id")]
    id = $content.attr("_id")
    if not Discussion.getContentInfo id, 'editable'
      $local(".discussion-edit").remove()
