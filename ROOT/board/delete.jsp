<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.io.*, java.util.UUID" %>
<%@ include file="../db.jsp" %>
<%
    // 로그인 체크
    String username = (String) session.getAttribute("username");
    Integer userIdx = (Integer) session.getAttribute("idx");
    if (username == null || userIdx == null) {
%>
<script>
    alert('로그인 후 이용해주세요.');
    location.href = '../passlogic/login.jsp';
</script>
<%
        return;
    }

    // CSRF 토큰 발급(없으면 생성)
    String csrf_token = (String) session.getAttribute("csrf_token");
    if (csrf_token == null) {
        csrf_token = UUID.randomUUID().toString().replace("-", "");
        session.setAttribute("csrf_token", csrf_token);
    }

    // POST 방식이 아닌 경우, 삭제 폼 보여주기(확인용)
    if (!"POST".equalsIgnoreCase(request.getMethod())) {
        int id = 0;
        try { id = Integer.parseInt(request.getParameter("id")); } catch (Exception e) {}
        if (id == 0) {
%>
<script>
    alert('잘못된 접근입니다.');
    location.href = '../index.jsp';
</script>
<%
            return;
        }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Sharks - 게시글 삭제</title>
    <link rel="stylesheet" href="../style.css">
    <link rel="icon" href="../img/sharks2.jpg" type="image/jpeg">
</head>
<body>
<jsp:include page="../nav.jsp" />
<div class="write">
    <h1>게시글 삭제 확인</h1>
    <form method="POST" action="delete.jsp">
        <input type="hidden" name="id" value="<%= id %>">
        <input type="hidden" name="csrf_token" value="<%= csrf_token %>">
        <p style="color:#e74c3c; font-weight:bold;">정말 이 게시글을 삭제하시겠습니까?</p>
        <ul>
            <li><input class="button" type="submit" value="삭제"></li>
            <li><button type="button" onclick="location.href='view.jsp?id=<%= id %>'">취소</button></li>
        </ul>
    </form>
</div>
</body>
</html>
<%
        return;
    }

    // --- [여기서부터 POST 방식 요청에 대해 삭제 처리] ---

    // CSRF 토큰 검증
    String reqToken = request.getParameter("csrf_token");
    String sessToken = (String) session.getAttribute("csrf_token");
    if (reqToken == null || !reqToken.equals(sessToken)) {
%>
<script>
    alert('잘못된 접근입니다.(CSRF 차단)');
    history.back();
</script>
<%
        return;
    }

    // 게시글 ID 파라미터 처리
    int id = 0;
    try {
        id = Integer.parseInt(request.getParameter("id"));
    } catch (Exception e) {
%>
<script>
    alert('잘못된 접근입니다.');
    location.href = '../index.jsp';
</script>
<%
        return;
    }
    if (id == 0) {
%>
<script>
    alert('잘못된 접근입니다.');
    location.href = '../index.jsp';
</script>
<%
        return;
    }

    // 게시글 조회
    String query = "SELECT user_idx, board_file FROM board_table WHERE board_idx = ?";
    PreparedStatement ps = db_conn.prepareStatement(query);
    ps.setInt(1, id);
    ResultSet rs = ps.executeQuery();

    if (!rs.next()) {
%>
<script>
    alert('존재하지 않는 게시글입니다.');
    location.href = '../index.jsp';
</script>
<%
        return;
    }

    int writerIdx = rs.getInt("user_idx");
    String boardFile = rs.getString("board_file");
    boolean isAdmin = "admin".equals(username);

    // 인가(Authorization) 체크 - 작성자 또는 관리자만 삭제 가능
    if (userIdx != writerIdx && !isAdmin) {
%>
<script>
    alert('삭제 권한이 없습니다.');
    location.href = '../index.jsp';
</script>
<%
        return;
    }

    // 파일 삭제 (파일 존재 시)
    if (boardFile != null && !boardFile.isEmpty()) {
        String uploadDir = application.getRealPath("../userupload/");
        File file = new File(uploadDir + File.separator + boardFile);
        if (file.exists()) file.delete();
    }

    // 게시글 삭제
    PreparedStatement deletePs = db_conn.prepareStatement("DELETE FROM board_table WHERE board_idx = ?");
    deletePs.setInt(1, id);
    int deleted = deletePs.executeUpdate();

    if (deleted > 0) {
%>
<script>
    alert('삭제되었습니다.');
    window.location.href = '../index.jsp';
</script>
<%
    } else {
%>
<script>
    alert('삭제에 실패했습니다.');
    window.location.href = '../index.jsp';
</script>
<%
    }

    // 자원 해제
    try { if (rs != null) rs.close(); } catch(Exception e) {}
    try { if (ps != null) ps.close(); } catch(Exception e) {}
    try { if (deletePs != null) deletePs.close(); } catch(Exception e) {}
    try { if (db_conn != null) db_conn.close(); } catch(Exception e) {}
%>
