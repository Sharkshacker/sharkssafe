<%@ page import="java.sql.*, java.io.*" %>
<%@ page contentType="application/octet-stream" pageEncoding="UTF-8" %>
<%@ include file="../db.jsp" %>

<%
    String idParam = request.getParameter("id");
    if (idParam == null) {
        out.println("다운로드할 게시글 ID가 제공되지 않았습니다.");
        return;
    }

    int boardIdx = 0;
    try {
        boardIdx = Integer.parseInt(idParam);
    } catch (NumberFormatException e) {
        out.println("잘못된 게시글 ID입니다.");
        return;
    }

    PreparedStatement pstmt = null;
    ResultSet rs = null;

    try {
        String sql = "SELECT board_file_blob, board_file_original_name FROM board_table WHERE board_idx = ?";
        pstmt = db_conn.prepareStatement(sql);
        pstmt.setInt(1, boardIdx);
        rs = pstmt.executeQuery();

        if (!rs.next()) {
            out.println("파일이 존재하지 않거나 첨부파일이 없습니다.");
            return;
        }

        String originalName = rs.getString("board_file_original_name");
        InputStream blobStream = rs.getBinaryStream("board_file_blob");

        if (blobStream == null) {
            out.println("첨부파일이 없습니다.");
            return;
        }

        // 한글/특수문자 파일명 처리 (브라우저별)
        String userAgent = request.getHeader("User-Agent");
        String downloadName = originalName;
        if (userAgent != null && (userAgent.contains("MSIE") || userAgent.contains("Trident"))) {
            downloadName = java.net.URLEncoder.encode(originalName, "UTF-8").replaceAll("\\+", " ");
        } else {
            downloadName = new String(originalName.getBytes("UTF-8"), "ISO-8859-1");
        }

        // HTTP 헤더 설정
        response.setContentType("application/octet-stream");
        response.setHeader("Content-Disposition", "attachment; filename=\"" + downloadName + "\"");
        response.setHeader("Content-Transfer-Encoding", "binary");
        response.setHeader("Pragma", "no-cache");
        response.setHeader("Expires", "-1");

        // 파일 스트림 복사
        byte[] buffer = new byte[8192];
        int bytesRead = -1;
        ServletOutputStream outStream = response.getOutputStream();

        while ((bytesRead = blobStream.read(buffer)) != -1) {
            outStream.write(buffer, 0, bytesRead);
        }
        outStream.flush();
        blobStream.close();

    } catch (Exception e) {
        out.println("파일 다운로드 중 오류 발생: " + e.getMessage());
    } finally {
        try { if (rs != null) rs.close(); } catch (Exception e) {}
        try { if (pstmt != null) pstmt.close(); } catch (Exception e) {}
        // db_conn 닫지 않음 (외부에서 관리하므로)
    }
%>
