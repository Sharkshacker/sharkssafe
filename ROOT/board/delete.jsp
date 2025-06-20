<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.io.*" %>
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
