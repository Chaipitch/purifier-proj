public with sharing class LineMessagingService {
  public class PushResult {
    public Boolean success = false;
    public String error;
  }

  public static PushResult pushText(String lineUserId, String text) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:LINE_Messaging_API/v2/bot/message/push');
    req.setMethod('POST');
    req.setTimeout(10000);
    req.setHeader('Content-Type', 'application/json');
    // LINE ignores a repeated request with the same retry key, so a retried send can't arrive twice.
    req.setHeader('X-Line-Retry-Key', UUID.randomUUID().toString());
    req.setBody(
      JSON.serialize(
        new Map<String, Object>{
          'to' => lineUserId,
          'messages' => new List<Object>{
            new Map<String, Object>{ 'type' => 'text', 'text' => text }
          }
        }
      )
    );

    PushResult result = new PushResult();
    try {
      HttpResponse res = new Http().send(req);
      result.success = res.getStatusCode() == 200;
      if (!result.success) {
        result.error = ('LINE ' +
          res.getStatusCode() +
          ': ' +
          res.getBody())
          .left(255);
      }
    } catch (CalloutException e) {
      result.error = e.getMessage().left(255);
    }
    return result;
  }
}
