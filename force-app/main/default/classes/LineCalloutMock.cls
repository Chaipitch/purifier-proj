// Test stand-in for the LINE Messaging API: answers every call with 200 and remembers the last body.
@IsTest
public class LineCalloutMock implements HttpCalloutMock {
  public Integer status = 200;
  public String lastBody;
  public Integer calls = 0;

  public HttpResponse respond(HttpRequest req) {
    calls++;
    lastBody = req.getBody();
    HttpResponse res = new HttpResponse();
    res.setStatusCode(status);
    res.setBody(
      req.getEndpoint().contains('/profile/')
        ? '{"displayName":"Test Friend"}'
        : '{}'
    );
    return res;
  }
}
