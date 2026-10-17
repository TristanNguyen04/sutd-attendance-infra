resource "aws_sqs_queue" "events_dlq" {
  count = local.has_queue ? 1 : 0

  name                      = "${local.full_name}-events-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "events" {
  count = local.has_queue ? 1 : 0

  name                       = "${local.full_name}-events"
  visibility_timeout_seconds = 60
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.events_dlq[0].arn
    maxReceiveCount     = 5
  })
}

resource "aws_cloudwatch_event_rule" "events" {
  for_each = local.subscriptions

  name           = "${local.full_name}-from-${each.key}"
  event_bus_name = var.event_bus_name

  event_pattern = jsonencode({
    source        = [each.value.source]
    "detail-type" = each.value.detail_types
  })
}

resource "aws_cloudwatch_event_target" "events" {
  for_each = local.subscriptions

  rule           = aws_cloudwatch_event_rule.events[each.key].name
  event_bus_name = var.event_bus_name
  target_id      = "sqs"
  arn            = aws_sqs_queue.events[0].arn
}

data "aws_iam_policy_document" "queue" {
  count = local.has_queue ? 1 : 0

  statement {
    sid       = "AllowEventBridge"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.events[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [for r in aws_cloudwatch_event_rule.events : r.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "events" {
  count = local.has_queue ? 1 : 0

  queue_url = aws_sqs_queue.events[0].url
  policy    = data.aws_iam_policy_document.queue[0].json
}
