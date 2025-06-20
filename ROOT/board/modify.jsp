<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.io.*, javax.servlet.http.*, javax.servlet.*, java.nio.file.Paths" %>
<%@ include file="../db.jsp" %>

<%!
    // HTML 태그 이스케이프 함수 (XSS 대응)
    public static String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#x27;");
    }
%>

<%
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

    // 작성자 검증 (권한 인가 강화)
    PreparedStatement ps = db_conn.prepareStatement("SELECT * FROM board_table WHERE board_idx = ?");
    ps.setInt(1, id);
    ResultSet board = ps.executeQuery();
    if (!board.next()) {
%>
<script>
    alert('존재하지 않는 게시글입니다.');
    location.href = '../index.jsp';
</script>
<%
        return;
    }

    int writerIdx = board.getInt("user_idx");
    boolean isAdmin = "admin".equals(username);
    if (userIdx != writerIdx && !isAdmin) {
%>
<script>
    alert('수정 권한이 없습니다.');
    location.href = '../index.jsp';
</script>
<%
        return;
    }

    // POST 요청 처리
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        request.setCharacterEncoding("UTF-8");
        String title = escapeHtml(request.getParameter("title"));    // XSS 대응
        String content = escapeHtml(request.getParameter("content")); // XSS 대응
        boolean secret = "1".equals(request.getParameter("secret"));
        boolean deleteFile = "1".equals(request.getParameter("delete_file"));

        // 파일(blob) 처리
        InputStream fileBlob = null;
        String fileOriginalName = null;
        String sqlUpdate;
        if (deleteFile) {
            sqlUpdate = "UPDATE board_table SET board_title=?, board_content=?, board_file_blob=NULL, board_file_original_name=NULL, board_secret=? WHERE board_idx=?";
            PreparedStatement update = db_conn.prepareStatement(sqlUpdate);
            update.setString(1, title);
            update.setString(2, content);
            update.setBoolean(3, secret);
            update.setInt(4, id);
            update.executeUpdate();
        } else {
            Part filePart = request.getPart("uploaded_file");
            if (filePart != null && filePart.getSize() > 0) {
                fileBlob = filePart.getInputStream();
                fileOriginalName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();

                sqlUpdate = "UPDATE board_table SET board_title=?, board_content=?, board_file_blob=?, board_file_original_name=?, board_secret=? WHERE board_idx=?";
                PreparedStatement update = db_conn.prepareStatement(sqlUpdate);
                update.setString(1, title);
                update.setString(2, content);
                update.setBlob(3, fileBlob);
                update.setString(4, fileOriginalName);
                update.setBoolean(5, secret);
                update.setInt(6, id);
                update.executeUpdate();
            } else {
                // 파일 업로드 없이 텍스트만 수정
                sqlUpdate = "UPDATE board_table SET board_title=?, board_content=?, board_secret=? WHERE board_idx=?";
                PreparedStatement update = db_conn.prepareStatement(sqlUpdate);
                update.setString(1, title);
                update.setString(2, content);
                update.setBoolean(3, secret);
                update.setInt(4, id);
                update.executeUpdate();
            }
        }
%>
<script>
    alert('수정 완료되었습니다!');
    location.href = 'view.jsp?id=<%= id %>';
</script>
<%
        return;
    }
%>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Sharks - 게시글 수정</title>
    <link rel="stylesheet" href="../style.css">
    <link rel="icon" href="../img/sharks2.jpg" type="image/jpeg">
</head>
<body>
<jsp:include page="../nav.jsp" />
<div class="write">
    <h1>글을 수정하세요.</h1>
    <hr/>
    <form method="POST" action="modify.jsp?id=<%= id %>" enctype="multipart/form-data">
        <table class="writeTable">
            <tr>
                <th width="50">제목</th>
                <td><input type="text" name="title" value="<%= escapeHtml(board.getString("board_title")) %>" required></td>
            </tr>
            <tr>
                <th>내용</th>
                <td><textarea name="content" rows="5" cols="40" required><%= escapeHtml(board.getString("board_content")) %></textarea></td>
            </tr>
            <tr>
                <th>파일 업로드</th>
                <td>
                    <input type="file" name="uploaded_file" />
                    <%
                        String currentFileName = board.getString("board_file_original_name");
                        if (currentFileName != null && !currentFileName.isEmpty()) {
                    %>
                        <br/><small>현재 파일: <%= escapeHtml(currentFileName) %></small>
                        <div>
                            <input type="checkbox" name="delete_file" value="1" id="delete_file_cb" />
                            <label for="delete_file_cb">기존 파일 삭제</label>
                        </div>
                    <% } %>
                </td>
            </tr>
            <tr>
                <th>비밀글</th>
                <td>
                    <label><input type="checkbox" name="secret" value="1" <%= board.getInt("board_secret") == 1 ? "checked" : "" %>> 비밀글</label>
                </td>
            </tr>
        </table>
        <ul>
            <li><input class="button" type="submit" value="수정 완료"></li>
            <li><button type="button" onclick="location.href='view.jsp?id=<%= id %>'">취소</button></li>
        </ul>
    </form>
</div>
<script src="../js/modal.js"></script>
</body>
</html>
<%
    try { if (board != null) board.close(); } catch(Exception e) {}
    try { if (ps != null) ps.close(); } catch(Exception e) {}
    try { if (db_conn != null) db_conn.close(); } catch(Exception e) {}
%>
