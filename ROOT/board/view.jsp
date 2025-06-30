<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, javax.servlet.http.*, javax.servlet.*, java.io.InputStream" %>
<%@ include file="../db.jsp" %>

<%!
    // HTML 엔터티 이스케이프 함수 (XSS 방지)
    public static String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#x27;");
    }

    // 본문 내 URL을 자동으로 a태그로 변환 (엔터티 escape 이후 적용)
    public static String autoLink(String text) {
        if (text == null) return "";
        // 정규식: http/https로 시작하는 부분만
        String urlRegex = "(https?://[\\w\\-\\.\\?\\,\\'/\\+&%\\$#_=:@!;]+)";
        // 엔터티 escape 먼저
        String safe = escapeHtml(text);
        // URL을 a태그로 감쌈
        safe = safe.replaceAll(urlRegex, "<a href=\"$1\" target=\"_blank\">$1</a>");
        // 줄바꿈 처리
        return safe.replaceAll("\n", "<br>");
    }
%>

<%
    String username = (String) session.getAttribute("username");
    Integer userIdx = session.getAttribute("idx") != null ? (Integer) session.getAttribute("idx") : -1;

    if (username == null) {
%>
    <script>
        alert('로그인 후 이용해주세요.');
        location.href = '../passlogic/login.jsp';
    </script>
<%
        return;
    }

    String idParam = request.getParameter("id");
    int id = 0;
    try {
        id = Integer.parseInt(idParam);
    } catch (Exception e) {}

    if (id == 0) {
%>
    <script>
        alert('잘못된 접근입니다.');
        location.href = '../index.jsp';
    </script>
<%
        return;
    }

    Statement stmt = null;
    ResultSet rs = null;
    ResultSet userRs = null;
    try {
        stmt = db_conn.createStatement();
        rs = stmt.executeQuery("SELECT * FROM board_table WHERE board_idx = " + id);

        if (!rs.next()) {
%>
    <script>
        alert('존재하지 않는 게시글입니다.');
        location.href = '../index.jsp';
    </script>
<%
            return;
        }

        String title = rs.getString("board_title");
        String content = rs.getString("board_content");  
        int writerIdx = rs.getInt("user_idx");
        String date = rs.getString("board_date");
        int views = rs.getInt("board_views");
        int secret = rs.getInt("board_secret");
        InputStream blob = rs.getBinaryStream("board_file_blob");
        String originName = rs.getString("board_file_original_name");

        boolean isAuthor = (writerIdx == userIdx);
        boolean isAdmin = "admin".equals(username);

        // 비밀글 권한 체크
        if (secret == 1 && !(isAuthor || isAdmin)) {
%>
    <script>
        alert('비밀글입니다. 권한이 없습니다.');
        location.href = '../index.jsp';
    </script>
<%
            return;
        }
        stmt.executeUpdate("UPDATE board_table SET board_views = board_views + 1 WHERE board_idx = " + id);
        userRs = stmt.executeQuery("SELECT user_id FROM user_table WHERE user_idx = " + writerIdx);
        String writerId = "";
        if (userRs.next()) {
            writerId = userRs.getString("user_id");
        }
%>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Sharks - 게시글</title>
    <link rel="stylesheet" href="../style.css">
    <link rel="icon" href="../img/sharks2.jpg" type="image/jpeg">
</head>
<body class="view-page">
    <jsp:include page="../nav.jsp" />

    <div class="view">
        <h2><%= escapeHtml(title) %></h2>
        <div class="user_info">
            <p><b>작성자</b> <%= escapeHtml(writerId) %> | <%= escapeHtml(date) %> | <b>조회수</b> <%= views %></p>
        </div>
        <hr>
        <div class="content">
            <%= autoLink(content) %>
        </div>
        <%
        if (blob != null && originName != null && !originName.isEmpty()) {
        %>
            <div class="attachment">
                <p>
                    <b>첨부파일:</b>
                    <a href="download.jsp?id=<%= id %>" target="_blank"><%= escapeHtml(originName) %></a>
                </p>
            </div>
        <%
        }
        %>
        <div class="viewButton">
            <ul>
                <li>
                    <button onclick="location.href='../index.jsp'">목록</button>
                </li>
                <% if (isAuthor || isAdmin) { %>
                <li>
                    <button onclick="location.href='modify.jsp?id=<%= id %>'">수정</button>
                </li>
                <li>
                    <button onclick="location.href='delete.jsp?id=<%= id %>'">삭제</button>
                </li>
                <% } %>
            </ul>
        </div>
    </div>
    <script src="../js/modal.js"></script>
</body>
</html>

<%
    } catch (Exception e) {
        out.println("DB 오류: " + escapeHtml(e.getMessage()));
    } finally {
        try { if (rs != null) rs.close(); } catch (Exception e) {}
        try { if (userRs != null) userRs.close(); } catch (Exception e) {}
        try { if (stmt != null) stmt.close(); } catch (Exception e) {}
        try { if (db_conn != null) db_conn.close(); } catch (Exception e) {}
    }
%>
