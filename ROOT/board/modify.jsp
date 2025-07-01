<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.io.*, javax.servlet.http.*, javax.servlet.*, java.nio.file.Paths, java.util.UUID" %>
<%@ include file="../db.jsp" %>

<%!
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

    // [CSRF 토큰 발급] 세션에 없으면 한 번만 생성
    String csrf_token = (String) session.getAttribute("csrf_token");
    if (csrf_token == null) {
        csrf_token = UUID.randomUUID().toString().replace("-", "");
        session.setAttribute("csrf_token", csrf_token);
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

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        // [CSRF 토큰 검증]
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

        request.setCharacterEncoding("UTF-8");
        String title = request.getParameter("title");
        String content = request.getParameter("content");
        boolean secret = "1".equals(request.getParameter("secret"));
        boolean deleteFile = "1".equals(request.getParameter("delete_file"));

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
            Part filePart = null;
            try { filePart = request.getPart("uploaded_file"); } catch (Exception e) {}

            if (filePart != null && filePart.getSize() > 0) {
                fileOriginalName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
                String fileExt = fileOriginalName.substring(fileOriginalName.lastIndexOf('.') + 1).toLowerCase();
                String mimeType = filePart.getContentType();

                boolean isAllowed = false;
                if ((mimeType.startsWith("image/") && fileExt.matches("jpg|jpeg|png|gif|bmp")) ||
                    (fileExt.equals("xlsx") && mimeType.equals("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")) ||
                    (fileExt.equals("hwp") && mimeType.equals("application/x-hwp"))) {
                    isAllowed = true;
                }

                if (!isAllowed) {
%>
<script>
    alert('허용되지 않은 파일 형식입니다. 이미지, 엑셀(xlsx), 한글(hwp)만 허용됩니다.');
    history.back();
</script>
<%
                    return;
                }

                fileBlob = filePart.getInputStream();
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
        <input type="hidden" name="csrf_token" value="<%= csrf_token %>">
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
